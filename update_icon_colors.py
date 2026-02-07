#!/usr/bin/env python3
"""
Update the icon colors to match the app's date badge colors:
- Sun and rays: #F39C12 (RGB: 243, 156, 18) - Morning color
- Moon: #5D4E75 (RGB: 93, 78, 117) - Evening color
"""

from PIL import Image

# Target colors from the app
SUN_COLOR = (243, 156, 18)  # Orange #F39C12 - Morning
MOON_COLOR = (93, 78, 117)  # Purple #5D4E75 - Evening

def update_icon_colors(input_path, output_path):
    """Update icon colors to match app date badge colors"""
    img = Image.open(input_path)
    
    # Convert to RGB if needed
    if img.mode == 'RGBA':
        # Create white background and composite
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Get image dimensions
    width, height = img.size
    pixels = img.load()
    
    # Process each pixel
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            
            # Skip white background (very light pixels)
            if r > 240 and g > 240 and b > 240:
                continue
            
            # First, check if pixel is purple/moon color (already correct or close to it)
            # Check if it's already purple or close to purple
            is_purple = (
                r < 120 and  # Low to medium red
                g < 100 and  # Low green
                b > 60 and  # Some blue
                abs(r - MOON_COLOR[0]) < 50 and  # Close to target purple red
                abs(g - MOON_COLOR[1]) < 50 and  # Close to target purple green
                abs(b - MOON_COLOR[2]) < 50  # Close to target purple blue
            )
            
            # Check if pixel is black/dark (moon - needs to be purple)
            is_black_dark = (
                r < 60 and  # Very low red
                g < 60 and  # Very low green
                b < 60  # Very low blue
            )
            
            # Replace colors - moon first, then everything else becomes sun
            if is_purple or is_black_dark:
                # Replace with moon color (purple)
                pixels[x, y] = MOON_COLOR
            else:
                # Everything else that's not white is sun/rays - replace with orange
                pixels[x, y] = SUN_COLOR
    
    # Save the updated image
    img.save(output_path)
    print(f"Updated icon saved to: {output_path}")

if __name__ == "__main__":
    input_path = "/RAID_Storage/AI Coding/Morning-and-Evening/color_morning_and_evening.png"
    output_path = "/RAID_Storage/AI Coding/Morning-and-Evening/color_morning_and_evening.png"  # Overwrite
    
    update_icon_colors(input_path, output_path)
    print("Icon color update complete!")

