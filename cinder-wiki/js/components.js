/**
 * CinderRPG Wiki - Component Manager
 * Loads and manages reusable HTML components
 */

class ComponentManager {
    constructor() {
        this.componentsLoaded = false;
        this.componentsCache = null;
        // Dynamically determine the correct path based on current location
        this.componentPath = this.getComponentPath();
    }

    /**
     * Get the correct path to components based on current page location
     */
    getComponentPath() {
        const path = window.location.pathname;
        
        // If we're in the root (index.html)
        if (path.endsWith('index.html') || path.endsWith('/') || !path.includes('/cinder-wiki/')) {
            return 'cinder-wiki/components/all-components.html';
        }
        // If we're in cinder-wiki/html/ folder
        else if (path.includes('/cinder-wiki/html/')) {
            return '../components/all-components.html';
        }
        // Default fallback
        return '../components/all-components.html';
    }

    /**
     * Load all components from the HTML file
     */
    async loadComponentsFile() {
        if (this.componentsCache) return this.componentsCache;
        
        console.log('Attempting to load components from:', this.componentPath);
        
        try {
            const response = await fetch(this.componentPath);
            console.log('Fetch response:', response.status, response.ok);
            
            if (!response.ok) throw new Error(`Failed to load components: ${response.status}`);
            
            const html = await response.text();
            console.log('Components HTML loaded, length:', html.length);
            
            const parser = new DOMParser();
            this.componentsCache = parser.parseFromString(html, 'text/html');
            console.log('Components parsed successfully');
            
            return this.componentsCache;
        } catch (error) {
            console.error('Error loading components:', error);
            console.error('Component path was:', this.componentPath);
            return null;
        }
    }

    /**
     * Get a specific component by template ID
     */
    async getComponent(templateId) {
        const doc = await this.loadComponentsFile();
        if (!doc) return null;
        
        const template = doc.getElementById(templateId);
        if (!template) {
            console.error(`Component template "${templateId}" not found`);
            return null;
        }
        
        return template.content.cloneNode(true);
    }

    /**
     * Insert component into target element
     */
    async insertComponent(templateId, targetSelector) {
        const target = document.querySelector(targetSelector);
        if (!target) {
            console.error(`Target element "${targetSelector}" not found`);
            return false;
        }

        const component = await this.getComponent(templateId);
        if (!component) return false;

        target.appendChild(component);
        return true;
    }

    /**
     * Load multiple components at once
     */
    async loadComponents(components) {
        // Add loading class to body
        document.body.classList.add('components-loading');
        
        const promises = components.map(({ templateId, targetSelector }) => 
            this.insertComponent(templateId, targetSelector)
        );
        
        await Promise.all(promises);
        this.componentsLoaded = true;
        
        // Fix relative paths based on current page location
        this.fixComponentPaths();
        
        // Initialize component scripts after loading
        this.initializeScripts();
        
        // Remove loading class and add loaded class
        document.body.classList.remove('components-loading');
        document.body.classList.add('components-loaded');
    }

    /**
     * Fix relative paths in components based on current page location
     */
    fixComponentPaths() {
        const path = window.location.pathname;
        const isRootPage = path.endsWith('index.html') || path.endsWith('/') || !path.includes('/cinder-wiki/');
        
        if (isRootPage) {
            // We're at root level, fix paths to point into cinder-wiki
            document.querySelectorAll('#header-slot a[href^="../"]').forEach(link => {
                link.href = link.getAttribute('href').replace('../', 'cinder-wiki/');
            });
            document.querySelectorAll('#header-slot a[href^="../../"]').forEach(link => {
                link.href = link.getAttribute('href').replace('../../', '');
            });
            document.querySelectorAll('#header-slot img[src^="../"]').forEach(img => {
                img.src = img.getAttribute('src').replace('../', 'cinder-wiki/');
            });
        }
        // If we're in cinder-wiki/html/, the relative paths are already correct
    }

    /**
     * Initialize all component scripts after loading
     */
    initializeScripts() {
        this.initNavigation();
        this.initLogoFallback();
        this.initBugModal();
        this.setActiveNavLink();
    }

    /**
     * Navigation toggle and dropdown logic
     */
    initNavigation() {
        const btn = document.querySelector('.nav-toggle');
        const nav = document.querySelector('.nav');
        
        if (!btn || !nav) return;

        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const expanded = btn.getAttribute('aria-expanded') === 'true';
            btn.setAttribute('aria-expanded', !expanded);
            nav.classList.toggle('open');
            document.body.classList.toggle('nav-open');
        });

        // Handle dropdown clicks on mobile
        const dropdowns = document.querySelectorAll('.has-dropdown');
        let isAnimating = false;
        
        dropdowns.forEach(dropdown => {
            const link = dropdown.querySelector('.nav-link');
            const dropdownMenu = dropdown.querySelector('.dropdown');
            
            if (link) {
                link.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    if (isAnimating) return;
                    isAnimating = true;
                    
                    // Close other dropdowns
                    dropdowns.forEach(d => {
                        if (d !== dropdown) d.classList.remove('touch-open');
                    });
                    
                    const isOpening = !dropdown.classList.contains('touch-open');
                    dropdown.classList.toggle('touch-open');
                    
                    if (isOpening && dropdownMenu) {
                        setTimeout(() => {
                            const navContainer = nav;
                            const dropdownBottom = dropdown.offsetTop + dropdown.offsetHeight;
                            
                            navContainer.scrollTo({
                                top: dropdownBottom - navContainer.clientHeight + 20,
                                behavior: 'smooth'
                            });
                        }, 100);
                    }
                    
                    setTimeout(() => { isAnimating = false; }, 250);
                });
            }
        });

        // Close dropdown when clicking other nav links (not dropdown items)
        const navLinks = document.querySelectorAll('.nav-list > li:not(.has-dropdown) > .nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                dropdowns.forEach(dropdown => {
                    dropdown.classList.remove('touch-open');
                });
            });
        });

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (nav.classList.contains('open')) {
                if (!nav.contains(e.target) && !btn.contains(e.target)) {
                    nav.classList.remove('open');
                    document.body.classList.remove('nav-open');
                    btn.setAttribute('aria-expanded', 'false');
                    dropdowns.forEach(dropdown => {
                        dropdown.classList.remove('touch-open');
                    });
                }
            }
        });

        // Close menu on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && nav.classList.contains('open')) {
                nav.classList.remove('open');
                document.body.classList.remove('nav-open');
                btn.setAttribute('aria-expanded', 'false');
                dropdowns.forEach(dropdown => {
                    dropdown.classList.remove('touch-open');
                });
            }
        });
    }

    /**
     * Logo fallback if image fails to load
     */
    initLogoFallback() {
        const img = document.querySelector('.brand-img');
        const svg = document.querySelector('.brand-fallback');
        if (!img) return;
        
        img.addEventListener('error', () => {
            img.style.display = 'none';
            if (svg) svg.style.display = 'inline-block';
        });
    }

    /**
     * Bug Report Modal functionality
     */
    initBugModal() {
        const modal = document.getElementById('bug-modal');
        const openBtns = document.querySelectorAll('.open-bug-modal, #open-bug-modal');
        const closeBtn = modal?.querySelector('.modal-close');
        const overlay = modal?.querySelector('.modal-overlay');

        if (!modal || openBtns.length === 0) return;

        function closeModal() {
            modal.classList.remove('modal-open');
            document.body.style.overflow = '';
            setTimeout(() => {
                modal.style.display = 'none';
            }, 300);
        }

        openBtns.forEach(btn => {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                modal.style.display = 'flex';
                modal.offsetHeight; // Force reflow
                modal.classList.add('modal-open');
                document.body.style.overflow = 'hidden';
            });
        });

        closeBtn?.addEventListener('click', closeModal);
        overlay?.addEventListener('click', closeModal);

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape' && modal.style.display === 'flex') {
                closeModal();
            }
        });
    }

    /**
     * Set active nav link based on current page URL
     */
    setActiveNavLink() {
        const currentPath = window.location.pathname;
        const navLinks = document.querySelectorAll('.nav-link');
        
        navLinks.forEach(link => {
            try {
                const linkPath = new URL(link.href, window.location.origin).pathname;
                
                // Normalize paths for comparison
                const normalizedCurrent = currentPath.endsWith('/') ? currentPath : currentPath + '/';
                const normalizedLink = linkPath.endsWith('/') ? linkPath : linkPath + '/';
                
                // Check for exact match or if it's the home page
                if (normalizedCurrent === normalizedLink || 
                    (currentPath === '/' && linkPath.includes('index.html')) ||
                    (currentPath.includes('index.html') && linkPath.includes('index.html'))) {
                    link.classList.add('active');
                } else {
                    link.classList.remove('active');
                }
            } catch (e) {
                // Skip external links or invalid URLs
                if (link.href === window.location.href) {
                    link.classList.add('active');
                }
            }
        });
    }
}

// Create global instance
window.ComponentManager = new ComponentManager();

/**
 * Auto-load components on DOMContentLoaded
 */
document.addEventListener('DOMContentLoaded', async () => {
    // Define default components to load
    const componentsToLoad = [
        { templateId: 'nav-component', targetSelector: '#header-slot' },
        { templateId: 'footer-component', targetSelector: '#footer-slot' },
        { templateId: 'modal-component', targetSelector: '#modal-slot' }
    ];

    // Load all components
    await window.ComponentManager.loadComponents(componentsToLoad);
    
    // Dispatch custom event when components are ready
    window.dispatchEvent(new CustomEvent('componentsLoaded'));
});
