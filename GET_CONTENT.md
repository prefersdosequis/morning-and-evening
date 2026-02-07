# How to Get the Full Devotional Content

The Morning and Evening devotional by Charles Spurgeon is in the public domain. Here are several ways to obtain the full content:

## Option 1: Download from CCEL (Recommended)

1. Visit: https://www.ccel.org/ccel/spurgeon/morneve.html
2. Look for download options (usually in the sidebar or at the top)
3. Download the **plain text** (.txt) or **single HTML file** version
4. Save it in this directory as `morneve.txt` or `morneve.html`
5. Run: `python3 parse_local_file.py morneve.txt` (or `.html`)

## Option 2: Use Project Gutenberg

1. Visit: https://www.gutenberg.org
2. Search for "Morning and Evening Spurgeon"
3. Download the plain text version
4. Save it in this directory
5. Run: `python3 parse_local_file.py <filename>`

## Option 3: Manual Download from CCEL Individual Pages

CCEL organizes the content by month. You can:
1. Visit: https://ccel.org/ccel/spurgeon/morneve.toc.html
2. Download individual month files
3. Combine them into one file
4. Run the parser script

## Option 4: Use the Fetch Script

Try running the automated fetch script:
```bash
python3 fetch_devotions.py
```

If it doesn't work (due to website structure changes), use one of the manual options above.

## After Obtaining the Content

Once you have the content file:

1. **For HTML files:**
   ```bash
   python3 parse_local_file.py morneve.html
   ```

2. **For text files:**
   ```bash
   python3 parse_local_file.py morneve.txt
   ```

3. The script will create `devotions.json` with all 730 devotions (365 days × 2)

4. Open `index.html` in your browser to use the app!

## File Format Expected

The parser looks for patterns like:
- "January 1, Morning" or "January 1. Morning"
- "January 1, Evening" or "January 1. Evening"

Most public domain sources use this format, so the parser should work with content from:
- CCEL (Christian Classics Ethereal Library)
- Project Gutenberg
- Other public domain repositories

## Troubleshooting

If the parser doesn't find devotions:
1. Check that your file contains date headers with "Morning" or "Evening"
2. Try opening the file and verify it has the full content (should be several hundred KB or more)
3. The file might need to be in UTF-8 encoding






