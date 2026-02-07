#!/usr/bin/env python3
"""
Modify the Morning and Evening icon colors:
- Sun: Orange (#F39C12 = RGB 243, 156, 18)
- Moon: Purple (#5D4E75 = RGB 93, 78, 117)
"""

from PIL import Image
import math

# Target colors
SUN_COLOR = (243, 156, 18)  # Orange #F39C12
MOON_COLOR = (93, 78, 117)  # Purple #5D4E75

def modify_icon_colors(input_path, output_path):
    """Modify icon colors:
    - All rays of light: orange (sun color)
    - Left half-moon shape: solid orange
    - Right half-moon shape: solid purple
    """
    img = Image.open(input_path)
    
    # Convert to RGB if needed (handles RGBA, P, etc.)
    if img.mode == 'RGBA':
        # Create white background and composite
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Get image dimensions
    width, height = img.size
    center_x, center_y = width // 2, height // 2
    
    # Process each pixel
    pixels = img.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            
            # Check if pixel is background (very light/white) - keep as is
            is_background = (r > 240 and g > 240 and b > 240)
            
            if is_background:
                # Keep background as is
                continue
            
            # Check if pixel is part of the image (not background)
            is_foreground = not is_background
            
            if not is_foreground:
                continue
            
            # Sun is in center-left, moon in center-right
            sun_center_x = width * 0.35  # Left of center
            sun_center_y = height * 0.5  # Vertical center
            moon_center_x = width * 0.65  # Right of center
            moon_center_y = height * 0.5  # Vertical center
            
            # Distance from sun center
            dx_sun = x - sun_center_x
            dy_sun = y - sun_center_y
            dist_sun = math.sqrt(dx_sun*dx_sun + dy_sun*dy_sun)
            
            # Distance from moon center
            dx_moon = x - moon_center_x
            dy_moon = y - moon_center_y
            dist_moon = math.sqrt(dx_moon*dx_moon + dy_moon*dy_moon)
            
            # Detect half-moon shapes FIRST - these take absolute priority
            # Calculate angle from center to exclude the right half-circle in bottom-left
            angle_moon = math.atan2(dy_moon, dx_moon)  # Angle in radians
            angle_sun = math.atan2(dy_sun, dx_sun)  # Angle in radians
            
            # Check pixel brightness to identify darker semicircles
            brightness = (r + g + b) / 3.0
            
            # Exclude the right half of a circle in the bottom-left of each crescent
            # This is a semicircle shape in the bottom-left quadrant
            # Bottom-left is angles between -pi and -pi/2 (180-270 degrees)
            is_bottom_left_angle_moon = (angle_moon < -math.pi/2 and angle_moon > -math.pi)
            is_bottom_left_angle_sun = (angle_sun < -math.pi/2 and angle_sun > -math.pi)
            
            # The darker semicircle: exclude pixels in bottom-left that are:
            # 1. In the bottom-left angle range
            # 2. At the semicircle distance (wider range to catch it all)
            # 3. AND darker than average (brightness check)
            exclude_semicircle_moon = (is_bottom_left_angle_moon and 
                                      dist_moon > width * 0.10 and dist_moon < width * 0.30 and
                                      brightness < 200)  # Darker pixels
            exclude_semicircle_sun = (is_bottom_left_angle_sun and 
                                     dist_sun > width * 0.10 and dist_sun < width * 0.30 and
                                     brightness < 200)  # Darker pixels
            
            # Right half-moon: crescent shape around moon center
            # Must be in crescent distance range, and not the excluded semicircle
            is_right_halfmoon = (dist_moon > width * 0.12 and dist_moon < width * 0.35 and
                                x > width * 0.52 and  # Right side only
                                not exclude_semicircle_moon)  # Exclude right half-circle in bottom-left
            
            # Left half-moon: crescent shape around sun center
            # Must be in crescent distance range, and not the excluded semicircle
            is_left_halfmoon = (dist_sun > width * 0.12 and dist_sun < width * 0.35 and
                               x < width * 0.48 and  # Left side only
                               y > height * 0.3 and y < height * 0.7 and  # Middle vertical region
                               not exclude_semicircle_sun)  # Exclude right half-circle in bottom-left
            
            # Detect oval/pill shapes - ALL oval pills should be orange
            # But NOT if they're part of a crescent (crescents take priority)
            is_oval_pill = False
            
            # Only check for pills if NOT part of a crescent
            if not is_right_halfmoon and not is_left_halfmoon:
                # Bottom right pill: entire area under and to the right of moon
                is_bottom_right_pill = (x > width * 0.52 and y > height * 0.52 and 
                                       (dist_moon > width * 0.20 or y > height * 0.58))
                
                # Top region: near top of image - these are pills
                is_top_region = (y < height * 0.3)
                # Bottom region: near bottom of image - these are pills
                is_bottom_region = (y > height * 0.7)
                
                # If in these regions and not background, it's an oval pill
                if (is_top_region or is_bottom_region or is_bottom_right_pill):
                    is_oval_pill = True
            
            # Apply colors - ONLY color specific shapes, NO left/right split
            if is_right_halfmoon:
                # Right half-moon (moon) is solid purple - highest priority
                pixels[x, y] = MOON_COLOR
            elif is_left_halfmoon:
                # Left half-moon (sun) is solid orange - second priority
                pixels[x, y] = SUN_COLOR
            elif is_oval_pill:
                # ALL oval pills are solid orange (sun)
                pixels[x, y] = SUN_COLOR
            # If not a crescent or pill, keep original color (NO left/right split)
    
    # Save the modified image
    img.save(output_path)
    print(f"Modified icon saved to: {output_path}")

if __name__ == "__main__":
    input_path = "/RAID_Storage/AI Coding/Morning-and-Evening/Morning_and_Evening.png"
    output_path = "/RAID_Storage/AI Coding/Morning-and-Evening/Morning_and_Evening.png"  # Overwrite original
    
    modify_icon_colors(input_path, output_path)
    print("Icon color modification complete! Original file updated.")

