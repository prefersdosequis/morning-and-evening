// Morning and Evening Devotional App
// Data structure for devotions (365 days × 2 = 730 pages)

class DevotionalApp {
    constructor() {
        this.currentPage = 1;
        this.totalPages = 730; // 365 days × 2 (morning + evening)
        this.devotions = [];
        
        this.init();
    }

    async init() {
        // Load devotions data
        await this.loadDevotions();
        
        // Set up event listeners
        document.getElementById('prevButton').addEventListener('click', () => this.goToPreviousPage());
        document.getElementById('nextButton').addEventListener('click', () => this.goToNextPage());
        
        // Keyboard navigation
        document.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowLeft') this.goToPreviousPage();
            if (e.key === 'ArrowRight') this.goToNextPage();
        });
        
        // Load saved page from localStorage
        const savedPage = localStorage.getItem('currentPage');
        if (savedPage) {
            this.currentPage = parseInt(savedPage, 10);
        }
        
        // Display initial page
        this.displayPage(this.currentPage);
    }

    async loadDevotions() {
        try {
            // Try to load from external file
            const response = await fetch('devotions.json');
            if (response.ok) {
                this.devotions = await response.json();
                this.totalPages = this.devotions.length;
                console.log(`Successfully loaded ${this.devotions.length} devotions`);
                return;
            } else {
                console.error('Failed to load devotions.json:', response.status, response.statusText);
            }
        } catch (error) {
            console.error('Error loading devotions.json:', error);
            // Check if it's a CORS/local file issue
            if (window.location.protocol === 'file:') {
                this.showServerMessage();
            }
        }
        
        // If file doesn't exist, use sample data structure
        // In production, you would load the full devotional content here
        console.warn('Using placeholder data. Please use a local server to load devotions.json');
        this.devotions = this.getSampleDevotions();
    }

    showServerMessage() {
        // Show a message to the user about using a local server
        const message = document.createElement('div');
        message.id = 'serverMessage';
        message.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: #e74c3c;
            color: white;
            padding: 20px 30px;
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
            z-index: 10000;
            max-width: 600px;
            text-align: center;
        `;
        message.innerHTML = `
            <h3 style="margin: 0 0 10px 0;">⚠️ Local Server Required</h3>
            <p style="margin: 0 0 15px 0;">To load the devotional content, you need to run a local server.</p>
            <p style="margin: 0 0 15px 0; font-size: 0.9em;">Run this command in the terminal:</p>
            <code style="background: rgba(0,0,0,0.2); padding: 8px 12px; border-radius: 4px; display: block; margin: 10px 0;">
                python3 -m http.server 8000
            </code>
            <p style="margin: 15px 0 0 0; font-size: 0.9em;">Then open: <strong>http://localhost:8000</strong></p>
            <button onclick="this.parentElement.remove()" style="margin-top: 15px; padding: 8px 20px; background: white; color: #e74c3c; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">
                Close
            </button>
        `;
        document.body.appendChild(message);
    }

    getSampleDevotions() {
        // Sample structure - replace with full devotional content
        const sample = [];
        
        // Generate sample entries for demonstration
        // In production, replace this with the actual devotional content
        for (let day = 1; day <= 365; day++) {
            // Morning devotion
            sample.push({
                type: 'morning',
                day: day,
                title: `Morning - Day ${day}`,
                content: `This is a placeholder for the morning devotion for day ${day}. 
                In the full version, this would contain the actual text from Charles Spurgeon's 
                "Morning and Evening" devotional. The content is available in the public domain 
                and can be obtained from sources like the Christian Classics Ethereal Library (CCEL).`
            });
            
            // Evening devotion
            sample.push({
                type: 'evening',
                day: day,
                title: `Evening - Day ${day}`,
                content: `This is a placeholder for the evening devotion for day ${day}. 
                In the full version, this would contain the actual text from Charles Spurgeon's 
                "Morning and Evening" devotional. The content is available in the public domain 
                and can be obtained from sources like the Christian Classics Ethereal Library (CCEL).`
            });
        }
        
        return sample;
    }

    displayPage(pageNumber) {
        if (pageNumber < 1 || pageNumber > this.totalPages) {
            return;
        }
        
        this.currentPage = pageNumber;
        
        // Save to localStorage
        localStorage.setItem('currentPage', pageNumber.toString());
        
        // Get devotion data
        const devotion = this.devotions[pageNumber - 1];
        
        if (!devotion) {
            console.error('Devotion not found for page', pageNumber);
            return;
        }
        
        // Update UI
        document.getElementById('devotionTitle').textContent = devotion.title;
        document.getElementById('devotionText').innerHTML = this.formatContent(devotion.content);
        document.getElementById('currentPageDisplay').textContent = pageNumber;
        document.getElementById('totalPagesDisplay').textContent = this.totalPages;
        
        // Update progress bar
        const progress = (pageNumber / this.totalPages) * 100;
        document.getElementById('progressFill').style.width = `${progress}%`;
        
        // Update navigation buttons
        document.getElementById('prevButton').disabled = pageNumber === 1;
        document.getElementById('nextButton').disabled = pageNumber === this.totalPages;
        
        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    formatContent(content) {
        // Format content - split by paragraphs and wrap in <p> tags
        if (typeof content === 'string') {
            // Remove reference numbers like [33], [34] before "Go to..." links
            content = content.replace(/\[\d+\]Go To (Morning|Evening) Reading/gi, '');
            
            // Remove separator lines (lines with only underscores or dashes)
            content = content.replace(/^_{10,}$/gm, '');
            
            // Split by double newlines for paragraphs, then filter and clean
            let paragraphs = content.split('\n\n')
                .map(p => p.trim())
                .filter(p => p && p.length > 0 && !/^[_\-\s]+$/.test(p));
            
            // First pass: combine split quoted verses
            // If a paragraph starts with a quote but doesn't end with one,
            // and the next paragraph ends with a quote, combine them
            const combinedParagraphs = [];
            for (let i = 0; i < paragraphs.length; i++) {
                let para = paragraphs[i].replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
                
                // Check if this paragraph starts with a quote but doesn't end with one
                const startsWithQuote = /^["']/.test(para);
                const endsWithQuote = /["']\.?$/.test(para);
                
                if (startsWithQuote && !endsWithQuote && i + 1 < paragraphs.length) {
                    // Try to combine with next paragraph
                    let nextPara = paragraphs[i + 1].replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
                    if (/["']\.?$/.test(nextPara)) {
                        // Combine them
                        para = para + ' ' + nextPara;
                        i++; // Skip the next paragraph since we combined it
                    }
                }
                
                combinedParagraphs.push(para);
            }
            
            return combinedParagraphs.map((para, index) => {
                // Skip empty paragraphs
                if (!para) return '';
                
                // Check if it's a quoted scripture verse (starts and ends with quotes)
                // Pattern: "text" or 'text' - typically the first verse of each devotion
                // Allow for optional period at the end, and handle both single and double quotes
                const quotedVersePattern = /^["'].+["']\.?$/;
                
                // Check if it's a scripture verse reference - comprehensive patterns
                // Pattern 1: Simple book name with chapter:verse (e.g., "Joshua 5:12", "Luke 8:13", "Psalm 22:14", "Genesis 1:4")
                const simpleVerseRef = /^[A-Z][a-zA-Z]+\s+\d+:\d+$/;
                
                // Pattern 2: Book name with multiple words (e.g., "Song of Solomon 1:4")
                const multiWordVerseRef = /^[A-Z][a-zA-Z\s]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+$/;
                
                // Pattern 3: Numbered books (e.g., "1 Peter 5:7", "2 Timothy 4:8", "2 Corinthians 7:6", "2 Samuel 15:23")
                const numberedBookPattern = /^\d+\s+[A-Z][a-zA-Z\s]+\s+\d+:\d+$/;
                
                // Pattern 4: Books with numbers and "of" (e.g., "1 Song of Solomon")
                const numberedWithOf = /^\d+\s+[A-Z][a-zA-Z\s]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+$/;
                
                // Check if it's a verse reference (book name + chapter:verse)
                // Always italicize if it matches any verse reference pattern
                const isVerseRef = simpleVerseRef.test(para) || 
                                  multiWordVerseRef.test(para) || 
                                  numberedBookPattern.test(para) ||
                                  numberedWithOf.test(para);
                
                // Check if it's a quoted scripture verse (starts and ends with quotes)
                // Quoted verses are wrapped in quotes and appear early in the devotion
                // Allow longer verses (up to 600 chars) and check first 8 paragraphs
                const isQuotedVerse = quotedVersePattern.test(para) && para.length < 600 && index < 8;
                
                // Also check for paragraphs that start with a quote in the first few positions
                // These are likely scripture verses even if they don't end with a quote (might be split)
                // But only if they're reasonably short and appear very early
                const startsWithQuote = /^["']/.test(para);
                const isEarlyQuoted = startsWithQuote && index < 2 && para.length < 400 && !para.includes('\n');
                
                // If it matches a verse reference pattern, it's definitely scripture (always italicize)
                // Also italicize early paragraphs that start with quotes (likely scripture verses)
                if (isVerseRef || isQuotedVerse || isEarlyQuoted) {
                    return `<p class="scripture">${para}</p>`;
                }
                
                // Regular paragraph
                return `<p>${para}</p>`;
            }).join('');
        }
        return `<p>${content}</p>`;
    }

    goToNextPage() {
        if (this.currentPage < this.totalPages) {
            this.displayPage(this.currentPage + 1);
        }
    }

    goToPreviousPage() {
        if (this.currentPage > 1) {
            this.displayPage(this.currentPage - 1);
        }
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new DevotionalApp();
});

