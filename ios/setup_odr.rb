require 'xcodeproj'
require 'fileutils'

# Configuration
project_path = 'Runner.xcodeproj'
audio_source_dir = '../assets/audio' # Path relative to the ios folder
resource_group_name = 'AudioResources'
target_name = 'Runner'

# Month boundaries for ODR tags
MONTHS = [
  { tag: 'audio_jan', start: 1, end: 31 },
  { tag: 'audio_feb', start: 32, end: 60 },
  { tag: 'audio_mar', start: 61, end: 91 },
  { tag: 'audio_apr', start: 92, end: 121 },
  { tag: 'audio_may', start: 122, end: 152 },
  { tag: 'audio_jun', start: 153, end: 182 },
  { tag: 'audio_jul', start: 183, end: 213 },
  { tag: 'audio_aug', start: 214, end: 244 },
  { tag: 'audio_sep', start: 245, end: 274 },
  { tag: 'audio_oct', start: 275, end: 305 },
  { tag: 'audio_nov', start: 306, end: 335 },
  { tag: 'audio_dec', start: 336, end: 366 }
]

def get_tag_for_day(day)
  MONTHS.find { |m| day >= m[:start] && day <= m[:end] }[:tag]
rescue
  nil
end

# 1. Open Project
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }

# 2. Create or find the AudioResources group in Xcode
group = project.main_group[resource_group_name] || project.main_group.new_group(resource_group_name)

puts "Mapping audio files to ODR tags..."

# 3. Iterate through morning and evening folders
['morning', 'evening'].each do |subfolder|
  dir_path = File.join(audio_source_dir, subfolder)
  next unless Dir.exist?(dir_path)

  Dir.glob("#{dir_path}/*.mp3").each do |file_path|
    filename = File.basename(file_path)
    day_number = filename.scan(/\d+/).first.to_i
    tag = get_tag_for_day(day_number)

    next unless tag

    # Create reference in Xcode group
    file_ref = group.files.find { |f| f.path == file_path } || group.new_file(file_path)
    
    # Ensure it's in the Resources Build Phase
    unless target.resources_build_phase.files_references.include?(file_ref)
      build_file = target.add_resources([file_ref])
    end

    # Apply ODR Tag
    # This adds the tag to the "On-Demand Resource Tags" attribute in the file's build settings
    target.resources_build_phase.files.each do |bf|
      if bf.file_ref.path == file_ref.path
        bf.settings ||= {}
        bf.settings['ASSET_TAGS'] = [tag]
      end
    end
  end
end

# 4. Save Project
project.save
puts "Successfully mapped files to ODR tags in Xcode."
