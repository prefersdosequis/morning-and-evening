# Morning and Evening - Charles Spurgeon Devotional App

A beautiful web application for reading Charles H. Spurgeon's "Morning and Evening" devotional. The app displays morning devotions on odd-numbered pages and evening devotions on even-numbered pages, creating a seamless reading experience through the entire year.

## Features

- **Beautiful, Modern UI**: Clean, responsive design with smooth animations
- **Easy Navigation**: Previous/Next buttons and keyboard arrow key support
- **Progress Tracking**: Visual progress bar showing reading progress
- **Persistent State**: Remembers your current page using browser localStorage
- **Responsive Design**: Works beautifully on desktop, tablet, and mobile devices

## Getting Started

### Option 1: Simple Setup (No Server Required)

1. Open `index.html` directly in your web browser
2. The app will work with sample placeholder content

### Option 2: Using a Local Server (Recommended)

For the best experience, especially when loading the full devotional content:

```bash
# Using Python 3
python -m http.server 8000

# Using Python 2
python -m SimpleHTTPServer 8000

# Using Node.js (if you have http-server installed)
npx http-server
```

Then open `http://localhost:8000` in your browser.

## Adding the Full Devotional Content

The app is currently set up with placeholder content. To add the full devotional text:

### Automated Method (Recommended)

1. **Download the content** from [CCEL](https://www.ccel.org/ccel/spurgeon/morneve.html) or [Project Gutenberg](https://www.gutenberg.org)
   - Save it as `morneve.txt` or `morneve.html` in this directory

2. **Run the parser script:**
   ```bash
   python3 parse_local_file.py morneve.txt
   ```
   (or `morneve.html` if you downloaded the HTML version)

3. The script will automatically create `devotions.json` with all 730 devotions!

### Alternative: Try Automated Fetch

You can also try the automated fetch script:
```bash
python3 fetch_devotions.py
```

**Note:** This may not work if CCEL's website structure has changed. If it doesn't work, use the manual download method above.

### Manual Method

If you prefer to create the JSON manually, see `GET_CONTENT.md` for detailed instructions. The app expects a JSON file (`devotions.json`) with this structure:

```json
[
  {
    "type": "morning",
    "day": 1,
    "title": "January 1 - Morning",
    "content": "Full devotional text here..."
  },
  {
    "type": "evening",
    "day": 1,
    "title": "January 1 - Evening",
    "content": "Full devotional text here..."
  }
  // ... continue for all 365 days (730 entries total)
]
```

For more detailed instructions, see `GET_CONTENT.md`.

## File Structure

```
Morning-and-Evening/
├── index.html              # Main HTML structure
├── styles.css              # Styling and responsive design
├── app.js                  # Application logic and navigation
├── devotions.json          # Devotional content (to be populated)
├── fetch_devotions.py      # Script to fetch content from CCEL
├── parse_local_file.py     # Script to parse downloaded content files
├── GET_CONTENT.md          # Detailed instructions for obtaining content
└── README.md               # This file
```

## Usage

- **Navigate**: Use the Previous/Next buttons or arrow keys (← →)
- **Progress**: The progress bar at the bottom shows your reading progress
- **State**: Your current page is automatically saved and restored when you return

## Customization

You can customize the app by modifying:

- **Colors**: Edit CSS variables in `styles.css` (lines 7-14)
- **Typography**: Adjust font sizes and families in `styles.css`
- **Layout**: Modify the HTML structure in `index.html`

## Browser Support

The app works in all modern browsers:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## License

This app is free to use. The devotional content by Charles H. Spurgeon is in the public domain.

## Notes

- The app uses localStorage to remember your current page
- All content is loaded client-side (no backend required)
- The app is fully functional offline once the content is loaded

