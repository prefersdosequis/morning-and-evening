#!/usr/bin/env ruby
#
# setup_odr.rb — Add audio MP3s to the Xcode project as On-Demand Resources.
#
# Prerequisites:
#   gem install xcodeproj   (already available if CocoaPods is installed)
#   Audio files present at  ../assets/audio/morning/*.mp3
#                           ../assets/audio/evening/*.mp3
#
# Usage:
#   cd ios
#   ruby setup_odr.rb
#
# What this script does:
#   1. Copies audio from assets/audio/ into ios/AudioResources/ with a type
#      prefix: morning_001.mp3, evening_001.mp3, etc.  Files are stored flat
#      (no subdirectories) so Xcode's ODR asset-pack bundling doesn't produce
#      "Multiple commands produce" collisions between same-numbered morning/
#      evening files.
#   2. Adds every MP3 to the Runner target's "Copy Bundle Resources" build phase
#   3. Tags each file with a monthly ODR tag  (audio_jan … audio_dec)
#   4. Registers the tags in KnownAssetTags so Xcode recognizes them
#
# The script is idempotent — re-running it removes the previous AudioResources
# group before re-adding everything.

require 'xcodeproj'
require 'fileutils'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR    = __dir__
PROJECT_PATH  = File.join(SCRIPT_DIR, 'Runner.xcodeproj')
AUDIO_SOURCE  = File.expand_path(File.join(SCRIPT_DIR, '..', 'assets', 'audio'))
AUDIO_DEST    = File.join(SCRIPT_DIR, 'AudioResources')
TARGET_NAME   = 'Runner'
TYPES         = %w[morning evening].freeze

# Day-to-month mapping.
# The devotion dataset always contains 366 entries (days 1-366).
# Day 60 = February 29; it is present every year in the dataset (the Dart layer
# skips it at runtime in non-leap years).  We include it in the audio_feb tag
# so the resource is available whenever the app requests it.
MONTH_TAGS = [
  { tag: 'audio_jan', first: 1,   last: 31  },  # Jan 1  – Jan 31
  { tag: 'audio_feb', first: 32,  last: 60  },  # Feb 1  – Feb 29
  { tag: 'audio_mar', first: 61,  last: 91  },  # Mar 1  – Mar 31
  { tag: 'audio_apr', first: 92,  last: 121 },  # Apr 1  – Apr 30
  { tag: 'audio_may', first: 122, last: 152 },  # May 1  – May 31
  { tag: 'audio_jun', first: 153, last: 182 },  # Jun 1  – Jun 30
  { tag: 'audio_jul', first: 183, last: 213 },  # Jul 1  – Jul 31
  { tag: 'audio_aug', first: 214, last: 244 },  # Aug 1  – Aug 31
  { tag: 'audio_sep', first: 245, last: 274 },  # Sep 1  – Sep 30
  { tag: 'audio_oct', first: 275, last: 305 },  # Oct 1  – Oct 31
  { tag: 'audio_nov', first: 306, last: 335 },  # Nov 1  – Nov 30
  { tag: 'audio_dec', first: 336, last: 366 },  # Dec 1  – Dec 31
].freeze

ALL_TAG_NAMES = MONTH_TAGS.map { |m| m[:tag] }.freeze

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def tag_for_day(day)
  entry = MONTH_TAGS.find { |m| day >= m[:first] && day <= m[:last] }
  raise "Day #{day} falls outside every month boundary (1-366)" unless entry
  entry[:tag]
end

def parse_day(filename)
  # Accepts both "042.mp3" (source) and "morning_042.mp3" (prefixed dest).
  m = filename.match(/(?:\A|_)(\d{3})\.mp3\z/i)
  raise "Cannot parse day number from filename: #{filename}" unless m
  m[1].to_i
end

# ---------------------------------------------------------------------------
# 1. Validate source audio
# ---------------------------------------------------------------------------

puts '=== iOS On-Demand Resources Setup ==='
puts

TYPES.each do |type|
  dir = File.join(AUDIO_SOURCE, type)
  unless File.directory?(dir)
    abort "ERROR: Source directory missing: #{dir}\n" \
          "       Ensure assets/audio/morning/ and assets/audio/evening/ exist."
  end
end

# ---------------------------------------------------------------------------
# 2. Copy audio files into ios/AudioResources/
# ---------------------------------------------------------------------------

puts "Copying audio files to #{AUDIO_DEST} (flat, with type prefix) ..."
FileUtils.rm_rf(AUDIO_DEST)
FileUtils.mkdir_p(AUDIO_DEST)

TYPES.each do |type|
  src  = File.join(AUDIO_SOURCE, type)

  mp3s = Dir.glob(File.join(src, '*.mp3')).sort
  abort "ERROR: No MP3 files in #{src}" if mp3s.empty?

  mp3s.each do |mp3_path|
    orig_name    = File.basename(mp3_path)          # "042.mp3"
    prefixed_name = "#{type}_#{orig_name}"          # "morning_042.mp3"
    FileUtils.cp(mp3_path, File.join(AUDIO_DEST, prefixed_name))
  end
  puts "  #{type}/: #{mp3s.length} files → #{type}_NNN.mp3"
end

# ---------------------------------------------------------------------------
# 3. Open Xcode project and locate the Runner target
# ---------------------------------------------------------------------------

puts "Opening #{PROJECT_PATH} ..."
project = Xcodeproj::Project.open(PROJECT_PATH)

target = project.targets.find { |t| t.name == TARGET_NAME }
abort "ERROR: Target '#{TARGET_NAME}' not found in project" unless target

resources_phase = target.resources_build_phase

# ---------------------------------------------------------------------------
# 4. Remove any previous AudioResources group (idempotent re-run)
# ---------------------------------------------------------------------------

old_group = project.main_group.children.find { |g| g.display_name == 'AudioResources' }
if old_group
  puts 'Removing previous AudioResources group ...'

  old_group.recursive_children.each do |child|
    next unless child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    resources_phase.files.dup.each do |bf|
      resources_phase.remove_build_file(bf) if bf.file_ref == child
    end
  end

  old_group.remove_from_project
end

# ---------------------------------------------------------------------------
# 5. Create group hierarchy and add every MP3
# ---------------------------------------------------------------------------

puts 'Adding audio files to Xcode project ...'

# Flat group — no morning/evening sub-groups.  All files are named
# {type}_{day}.mp3 so there are no basename collisions within an ODR pack.
audio_group = project.main_group.new_group('AudioResources', 'AudioResources')

files_added  = 0
tag_counts   = Hash.new(0)

Dir.glob(File.join(AUDIO_DEST, '*.mp3')).sort.each do |mp3_path|
  filename = File.basename(mp3_path)   # "morning_042.mp3"
  day      = parse_day(filename)
  tag      = tag_for_day(day)

  file_ref = audio_group.new_reference(filename)
  file_ref.last_known_file_type = 'audio.mpeg3'

  build_file = resources_phase.add_file_reference(file_ref)
  build_file.settings = { 'ASSET_TAGS' => [tag] }

  files_added += 1
  tag_counts[tag] += 1
end

puts "  #{files_added} files added to Copy Bundle Resources"

# ---------------------------------------------------------------------------
# 6. Register all ODR tags in project-level KnownAssetTags
# ---------------------------------------------------------------------------

puts 'Registering ODR tags ...'
attrs = project.root_object.attributes || {}
attrs['KnownAssetTags'] = ALL_TAG_NAMES
project.root_object.attributes = attrs

# ---------------------------------------------------------------------------
# 7. Save
# ---------------------------------------------------------------------------

project.save
puts
puts 'Tag distribution:'

MONTH_TAGS.each do |m|
  count = tag_counts[m[:tag]]
  days  = m[:last] - m[:first] + 1
  # Each day has morning_NNN.mp3 + evening_NNN.mp3 → expected = days * 2
  puts "  %-12s %3d files  (days %3d–%3d, %2d days)" % [m[:tag], count, m[:first], m[:last], days]
end

puts
puts "Total: #{files_added} files across #{ALL_TAG_NAMES.length} ODR tags"
puts
puts 'Next steps:'
puts '  1. Open ios/Runner.xcworkspace in Xcode'
puts '  2. Build & run to verify resources compile'
puts '  3. Product > Archive to upload with ODR to App Store Connect'
