/* ============================================
   Lore Page JavaScript
   CINDER RPG - Interactive Filtering & Slider
   ============================================ */

// ============================================
// Global State
// ============================================
let currentSlideIndex = 0;
let cardsPerView = 4;
let activeFilters = new Set(['all']);
let allLoreCards = [];
let filteredLoreCards = [];

// ============================================
// Modal State & Data
// ============================================
const loreData = {
    'ashen-king': {
        icon: 'ra ra-crown',
        title: 'The Ashen King',
        category: 'Historical Figure',
        content: `
            <h4>The Fall of a Kingdom</h4>
            <p>King Malachar III ruled the prosperous kingdom of Solheim during the 50th year of Sol. His reign was marked by peace and prosperity, but beneath the surface, the king harbored a terrible fear—the fear of death.</p>

            <h4>The Dark Ritual</h4>
            <p>In his obsession with immortality, Malachar uncovered an ancient tome hidden in the royal archives. The text promised eternal life through a ritual that would bind his soul to flame itself. What he didn't realize was the true cost of such power.</p>

            <ul>
                <li><strong>The Preparation:</strong> For five years, Malachar gathered rare components—phoenix ash, dragon's blood, and the tears of those who willingly gave their lives.</li>
                <li><strong>The Ritual Night:</strong> On the winter solstice, as the kingdom celebrated, Malachar performed the ritual in secret.</li>
                <li><strong>The Catastrophe:</strong> The spell spiraled out of control, releasing a wave of dark flame that consumed the entire kingdom in minutes.</li>
            </ul>

            <div class="info-box">
                <p><strong>Legacy:</strong> The Ashen King's crown remains as a cursed artifact. Those who wear it gain immense power over flame, but slowly lose their humanity, consumed by the same obsession that destroyed Malachar.</p>
            </div>

            <h4>Current Status</h4>
            <p>Some say the Ashen King still exists, trapped between life and death, wandering the ruins of his former kingdom. Adventurers who venture to the Dead Throne report seeing a spectral figure wearing a burning crown.</p>
        `
    },
    'ember-children': {
        icon: 'users',
        title: 'Children of Ember',
        category: 'Race',
        content: `
            <h4>Origin</h4>
            <p>The Children of Ember were not born—they emerged. When the Great Burning consumed the land, some souls refused to perish. Instead, they transformed, their mortal forms reforged in flame and ash.</p>

            <h4>Physical Characteristics</h4>
            <ul>
                <li><strong>Skin:</strong> Ranges from ashen gray to warm copper, with faint ember-like veins that glow in darkness</li>
                <li><strong>Eyes:</strong> Burn with an inner light—orange, red, or gold in color</li>
                <li><strong>Hair:</strong> Often appears to shimmer like heat waves; some have hair that actually smolders</li>
                <li><strong>Temperature:</strong> Their body temperature is naturally higher, allowing them to survive in extreme heat</li>
            </ul>

            <h4>Abilities & Culture</h4>
            <p>Children of Ember possess innate fire resistance and can manipulate small flames. Their society values transformation and rebirth, seeing destruction as a natural part of the cycle of existence.</p>

            <div class="info-box">
                <p><strong>Cultural Practice:</strong> When a Child of Ember dies, their body ignites and turns to ash. These ashes are collected and used to create sacred art that preserves their memories.</p>
            </div>

            <h4>Relations with Other Races</h4>
            <p>Many fear the Children of Ember, seeing them as living reminders of the apocalypse. However, others recognize them as survivors who have adapted to a harsh new world. Their knowledge of fire magic is unparalleled.</p>
        `
    },
    'sorath': {
        icon: 'ra ra-angel-wings',
        title: 'Sorath, the Scorched God',
        category: 'Deity',
        content: `
            <h4>The God of Transformation</h4>
            <p>Sorath is an ancient deity whose worship predates even the Great Burning. Known as the Scorched God, Sorath teaches that fire is not merely destruction—it is the ultimate form of change and purification.</p>

            <h4>Teachings & Philosophy</h4>
            <ul>
                <li><strong>Embrace Change:</strong> Nothing in the world is permanent. To resist change is to resist the natural order.</li>
                <li><strong>Purification by Flame:</strong> Fire burns away impurity, leaving only what is essential and true.</li>
                <li><strong>Rebirth:</strong> From ashes, new life emerges stronger than before.</li>
                <li><strong>Sacrifice:</strong> True transformation requires giving up something precious.</li>
            </ul>

            <h4>Rituals & Worship</h4>
            <p>Followers of Sorath practice fire-walking ceremonies, symbolic burnings of their past possessions, and meditation within heat. The most devout undergo the Trial of Embers—a dangerous ritual that tests their commitment.</p>

            <div class="info-box">
                <p><strong>The Sacred Flame:</strong> Every temple of Sorath maintains an eternal flame that has never been extinguished. To let this flame die is considered the greatest heresy.</p>
            </div>

            <h4>Divine Intervention</h4>
            <p>Sorath rarely intervenes directly in mortal affairs, but when he does, it is always through fire. Clerics of Sorath can channel his power to heal through controlled burning, remove curses, or grant visions through flame-reading.</p>
        `
    },
    'great-burning': {
        icon: 'ra ra-burning-embers',
        title: 'The Great Burning',
        category: 'Major Event',
        content: `
            <h4>The Day the World Changed</h4>
            <p>The Great Burning is the single most catastrophic event in recorded history. In the year 98 of Sol, a wave of dark flame swept across the continent, reducing entire civilizations to ash in a matter of hours.</p>

            <h4>Timeline of Destruction</h4>
            <ul>
                <li><strong>Hour 0:</strong> The ritual completes in the Dead Throne. A pillar of black flame erupts skyward.</li>
                <li><strong>Hour 3:</strong> The flame spreads outward at impossible speed, consuming everything in its path.</li>
                <li><strong>Hour 12:</strong> Major cities report widespread panic as the sky darkens with ash.</li>
                <li><strong>Day 1:</strong> Half the continent is engulfed. Refugees flee in all directions.</li>
                <li><strong>Week 1:</strong> The flame finally subsides, but the ash continues to fall like black snow.</li>
            </ul>

            <h4>Immediate Aftermath</h4>
            <p>The sun disappeared behind a veil of ash that would persist for nearly a century. Crops failed. Rivers turned black. Entire ecosystems collapsed. Survivors estimated that 90% of the population perished.</p>

            <div class="info-box">
                <p><strong>The Century of Darkness:</strong> For 100 years, the world existed in twilight. Only the hardiest species survived. This period is known as the Age of Ash.</p>
            </div>

            <h4>Theories on the Cause</h4>
            <p>While most historians blame the Ashen King's ritual, some scholars propose alternative theories:</p>
            <ul>
                <li>A volcanic super-eruption triggered by the ritual</li>
                <li>Divine punishment from the gods</li>
                <li>An ancient weapon accidentally unleashed</li>
                <li>A convergence of magical ley lines gone wrong</li>
            </ul>

            <h4>Long-term Impact</h4>
            <p>The Great Burning fundamentally reshaped the world. New races emerged. Magic became unpredictable. The geography itself changed as ash settled and reshaped the landscape. Society had to be rebuilt from scratch.</p>
        `
    },
    'cinder-wyrms': {
        icon: 'ra ra-dragon',
        title: 'Cinder Wyrms',
        category: 'Creature',
        content: `
            <h4>Ancient Predators</h4>
            <p>Cinder Wyrms are massive serpentine creatures that dwell in volcanic regions and deep beneath the earth. They are believed to predate human civilization by millennia, possibly even predating the gods themselves.</p>

            <h4>Physical Description</h4>
            <ul>
                <li><strong>Size:</strong> Adult wyrms can reach lengths of 40-60 feet</li>
                <li><strong>Scales:</strong> Made of a mineral similar to obsidian, glowing with internal heat</li>
                <li><strong>Breath:</strong> Exhales superheated gas capable of melting steel and stone</li>
                <li><strong>Eyes:</strong> Multiple sets that can see heat signatures through solid rock</li>
                <li><strong>Movement:</strong> Can burrow through solid stone as if swimming through water</li>
            </ul>

            <h4>Behavior & Intelligence</h4>
            <p>Contrary to popular belief, Cinder Wyrms are highly intelligent. They possess long memories and can hold grudges for centuries. Some scholars have successfully communicated with wyrms, learning ancient secrets in exchange for magical items.</p>

            <div class="info-box">
                <p><strong>Dragon's Hoard:</strong> Cinder Wyrms are drawn to enchanted items, particularly those with fire magic. They collect these in vast underground lairs, creating treasure troves of immense value—and danger.</p>
            </div>

            <h4>Life Cycle</h4>
            <p>Wyrms are extremely long-lived, with some specimens estimated to be over 1,000 years old. They reproduce rarely, laying clutches of crystalline eggs deep in volcanic chambers. Young wyrms are born with an instinctive knowledge passed down through generations.</p>

            <h4>Interaction with Civilization</h4>
            <p>Most encounters with Cinder Wyrms end in violence, but a few exceptional individuals have formed pacts with these creatures. The Scorched Citadel is rumored to be protected by an ancient wyrm named Ignathar, who safeguards the fortress in exchange for regular offerings of enchanted weapons.</p>
        `
    },
    'scorched-citadel': {
        icon: 'map-pin',
        title: 'The Scorched Citadel',
        category: 'Location',
        content: `
            <h4>Fortress of Flame</h4>
            <p>The Scorched Citadel stands as a testament to survival and adaptation. Built within the caldera of an active volcano, it serves as the last sanctuary for those who embrace fire rather than fear it.</p>

            <h4>Architecture & Design</h4>
            <ul>
                <li><strong>Walls:</strong> Constructed from volcanic obsidian reinforced with ancient magic</li>
                <li><strong>Gates:</strong> Massive doors that glow with protective runes, only opening for those permitted entry</li>
                <li><strong>Towers:</strong> Seven spires that channel geothermal energy into defensive wards</li>
                <li><strong>Interior:</strong> Surprisingly cool despite the location, thanks to clever magical climate control</li>
            </ul>

            <h4>The Founding</h4>
            <p>Established in the year 105 of Sol by survivors of the Great Burning, the Citadel began as a desperate refuge. Its founders—a coalition of fire mages, Children of Ember, and forge masters—recognized that the volcano's heat could be harnessed for protection.</p>

            <div class="info-box">
                <p><strong>The Heart Forge:</strong> At the center of the Citadel lies the legendary Heart Forge, where weapons and armor of unparalleled quality are created using pure volcanic heat. Items forged here are highly sought after.</p>
            </div>

            <h4>Society & Culture</h4>
            <p>The Citadel operates as a meritocracy. Those who demonstrate skill in fire magic, smithing, or survival earn respect regardless of their origin. The community values resilience, innovation, and mutual protection.</p>

            <h4>Strategic Importance</h4>
            <p>Throughout history, many have attempted to conquer the Scorched Citadel for its forges and strategic position. All have failed. The combination of natural defenses, magical wards, and the rumored wyrm guardian make it virtually impregnable.</p>

            <h4>Access & Trade</h4>
            <p>The Citadel maintains limited trade with the outside world. Merchants brave enough to make the journey can acquire exceptional weapons and rare volcanic materials. However, entry requires sponsorship from a current resident—trust is not given freely.</p>
        `
    },
    'ashborn': {
        icon: 'users',
        title: 'The Ashborn',
        category: 'Race',
        content: `
            <h4>Children of the Wasteland</h4>
            <p>The Ashborn are a race that evolved to thrive in the toxic ash-choked wastelands left by the Great Burning. They were once human, but a century of living in extreme conditions fundamentally changed them.</p>

            <h4>Adaptations</h4>
            <ul>
                <li><strong>Respiration:</strong> Their lungs can filter ash and toxic particles from the air</li>
                <li><strong>Vision:</strong> Can see clearly through thick smoke and ash storms</li>
                <li><strong>Heat Sense:</strong> Possess the ability to detect heat signatures, allowing them to find life in desolate areas</li>
                <li><strong>Pale Skin:</strong> Lack of sunlight during the Century of Darkness caused permanent pigmentation loss</li>
                <li><strong>Endurance:</strong> Require less food and water than typical humans</li>
            </ul>

            <h4>Society & Settlements</h4>
            <p>Ashborn live in hidden communities built within ruins and underground chambers. Their settlements are nearly invisible to outsiders, camouflaged by ash and debris. They have developed unique building techniques using compressed ash-brick.</p>

            <div class="info-box">
                <p><strong>Ash Reading:</strong> Ashborn shamans practice a form of divination by reading patterns in ash. They believe the ashes of the dead contain echoes of memory and can provide guidance.</p>
            </div>

            <h4>Culture & Beliefs</h4>
            <p>Ashborn culture emphasizes pragmatism and resourcefulness. Waste is unthinkable when resources are scarce. They honor their ancestors by incorporating ash from cremated family members into tools and artwork.</p>

            <h4>Relations with Others</h4>
            <p>For decades, the Ashborn were thought to be myths—ghost stories told by travelers. When they were finally discovered in the year 157 of Sol, it shocked the world. Initial contact was tense, but gradually, the Ashborn have begun integrating with other societies, serving as guides through the dangerous wastelands.</p>

            <h4>Unique Skills</h4>
            <p>Ashborn make exceptional scouts, trackers, and salvagers. Their ability to survive in environments that would kill others makes them invaluable for expeditions into the most dangerous regions of the world.</p>
        `
    },
    'lady-emberlyn': {
        icon: 'ra ra-crown',
        title: 'Lady Emberlyn',
        category: 'Historical Figure',
        content: `
            <h4>The Flame's Champion</h4>
            <p>Lady Emberlyn Ashthorne was the most powerful pyromancer of her generation. Born in the year 120 of Sol, she grew up in a world still recovering from the Great Burning, learning to harness fire not for destruction, but for protection and renewal.</p>

            <h4>Early Life</h4>
            <ul>
                <li><strong>Birth:</strong> Discovered as an infant in the smoldering ruins of a village, somehow unharmed by the flames</li>
                <li><strong>Training:</strong> Raised and trained by the Scorched Citadel's fire masters</li>
                <li><strong>Talent:</strong> Demonstrated unprecedented control over flame, able to shape it into complex forms</li>
                <li><strong>Philosophy:</strong> Believed fire should be a tool of creation, not destruction</li>
            </ul>

            <h4>The Ice Invasion</h4>
            <p>In the year 149 of Sol, a rift opened in the frozen north. Ice elementals poured through—beings of pure cold intent on extinguishing all flame and freezing the world. The threat was existential. If they succeeded, the world would become a frozen wasteland.</p>

            <div class="info-box">
                <p><strong>The Final Stand:</strong> For three days, Emberlyn held the front line, turning back wave after wave of ice elementals. Her soldiers reported that she seemed to burn brighter with each passing hour, as if becoming flame itself.</p>
            </div>

            <h4>The Eternal Pyre</h4>
            <p>On the fourth day, realizing that conventional magic couldn't seal the rift, Emberlyn made a choice. She channeled her entire life force—every drop of magical power she possessed—into a single, unprecedented spell.</p>

            <p>The result was the Eternal Pyre, a flame of such intensity and purity that it sealed the rift permanently and banished the ice elementals. But the spell consumed Emberlyn completely. Witnesses said her body turned to pure light before vanishing, leaving only the flame behind.</p>

            <h4>Legacy</h4>
            <p>The Eternal Pyre still burns, 50 years later, without fuel or tending. It has become a pilgrimage site, a monument to ultimate sacrifice. Pyromancers visit to pay respects and meditate on the flame's meaning.</p>

            <p>Some claim to hear Emberlyn's voice in the crackle of the flames, offering guidance to those pure of heart. Others believe she transcended mortality entirely, becoming one with fire itself—watching over the world she saved.</p>
        `
    }
};

// ============================================
// Initialize on Page Load
// ============================================
document.addEventListener('DOMContentLoaded', function() {
    // Initialize Lucide icons
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }

    // Initialize slider
    initializeSlider();
    
    // Set up filter buttons for lore cards
    setupLoreFilters();
    
    // Set up timeline filters
    setupTimelineFilters();
    
    // Update responsive cards per view
    updateCardsPerView();
    window.addEventListener('resize', updateCardsPerView);
});

// ============================================
// Slider Functions
// ============================================
function initializeSlider() {
    allLoreCards = Array.from(document.querySelectorAll('.lore-card'));
    filteredLoreCards = [...allLoreCards];
    
    updateCardsPerView();
    updateSlider();
    createIndicators();
    
    // Navigation buttons
    const prevBtn = document.getElementById('slider-prev');
    const nextBtn = document.getElementById('slider-next');
    
    if (prevBtn) prevBtn.addEventListener('click', () => navigateSlider(-1));
    if (nextBtn) nextBtn.addEventListener('click', () => navigateSlider(1));
    
    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowLeft') navigateSlider(-1);
        if (e.key === 'ArrowRight') navigateSlider(1);
    });
}

function updateCardsPerView() {
    const width = window.innerWidth;
    if (width <= 480) {
        cardsPerView = 1;
    } else if (width <= 768) {
        cardsPerView = 2;
    } else if (width <= 1024) {
        cardsPerView = 3;
    } else {
        cardsPerView = 4;
    }
    updateSlider();
    createIndicators();
}

function updateSlider() {
    const track = document.getElementById('lore-cards-track');
    if (!track) return;
    
    const cardWidth = 100 / cardsPerView;
    const maxIndex = Math.max(0, filteredLoreCards.length - cardsPerView);
    
    // Clamp current index
    currentSlideIndex = Math.min(currentSlideIndex, maxIndex);
    
    // Calculate transform
    const translateX = -(currentSlideIndex * cardWidth);
    track.style.transform = `translateX(${translateX}%)`;
    
    // Update navigation buttons
    updateNavigationButtons();
    updateIndicatorsState();
}

function navigateSlider(direction) {
    const maxIndex = Math.max(0, filteredLoreCards.length - cardsPerView);
    currentSlideIndex += direction;
    currentSlideIndex = Math.max(0, Math.min(currentSlideIndex, maxIndex));
    updateSlider();
}

function goToSlide(index) {
    currentSlideIndex = index;
    updateSlider();
}

function updateNavigationButtons() {
    const prevBtn = document.getElementById('slider-prev');
    const nextBtn = document.getElementById('slider-next');
    const maxIndex = Math.max(0, filteredLoreCards.length - cardsPerView);
    
    if (prevBtn) prevBtn.disabled = currentSlideIndex === 0;
    if (nextBtn) nextBtn.disabled = currentSlideIndex >= maxIndex;
}

function createIndicators() {
    const container = document.getElementById('slider-indicators');
    if (!container) return;
    
    container.innerHTML = '';
    const numSlides = Math.ceil(filteredLoreCards.length / cardsPerView);
    
    for (let i = 0; i < numSlides; i++) {
        const indicator = document.createElement('div');
        indicator.className = 'slider-indicator';
        if (i === currentSlideIndex) indicator.classList.add('active');
        indicator.addEventListener('click', () => goToSlide(i));
        container.appendChild(indicator);
    }
}

function updateIndicatorsState() {
    const indicators = document.querySelectorAll('.slider-indicator');
    indicators.forEach((indicator, index) => {
        indicator.classList.toggle('active', index === currentSlideIndex);
    });
}

// ============================================
// Lore Card Filtering
// ============================================
function setupLoreFilters() {
    const filterButtons = document.querySelectorAll('.lore-filter-btn');
    
    filterButtons.forEach(button => {
        button.addEventListener('click', () => {
            const category = button.dataset.category;
            
            if (category === 'all') {
                // Clear all filters and activate "All"
                filterButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');
                activeFilters.clear();
                activeFilters.add('all');
            } else {
                // Remove "All" if present
                activeFilters.delete('all');
                const allButton = document.querySelector('.lore-filter-btn[data-category="all"]');
                if (allButton) allButton.classList.remove('active');
                
                // Toggle this filter
                if (activeFilters.has(category)) {
                    activeFilters.delete(category);
                    button.classList.remove('active');
                } else {
                    activeFilters.add(category);
                    button.classList.add('active');
                }
                
                // If no filters active, default to "All"
                if (activeFilters.size === 0) {
                    activeFilters.add('all');
                    if (allButton) allButton.classList.add('active');
                }
            }
            
            filterLoreCards();
        });
    });
}

function filterLoreCards() {
    filteredLoreCards = [];
    
    allLoreCards.forEach(card => {
        const cardCategories = card.dataset.categories.split(' ');
        const shouldShow = activeFilters.has('all') || 
                          cardCategories.some(cat => activeFilters.has(cat));
        
        if (shouldShow) {
            filteredLoreCards.push(card);
            card.classList.remove('hidden');
        } else {
            card.classList.add('hidden');
        }
    });
    
    // Reset to first slide and update
    currentSlideIndex = 0;
    updateSlider();
    createIndicators();
}

// ============================================
// Timeline Filtering
// ============================================
function setupTimelineFilters() {
    const timelineButtons = document.querySelectorAll('.timeline-btn');
    
    timelineButtons.forEach(button => {
        button.addEventListener('click', () => {
            // Update active state
            timelineButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            // Filter events
            const era = button.dataset.era;
            filterTimelineEvents(era);
        });
    });
}

function filterTimelineEvents(era) {
    const events = document.querySelectorAll('.timeline-event');
    
    events.forEach(event => {
        if (era === 'all' || event.dataset.era === era) {
            event.classList.remove('hidden');
            // Trigger re-animation
            event.style.animation = 'none';
            setTimeout(() => {
                event.style.animation = '';
            }, 10);
        } else {
            event.classList.add('hidden');
        }
    });
}

// ============================================
// Modal Functions
// ============================================
function openLoreModal(loreId) {
    const modal = document.getElementById('lore-modal');
    const data = loreData[loreId];
    
    if (!modal || !data) return;
    
    // Update modal content
    const modalIcon = document.getElementById('modal-icon');
    const modalTitle = document.getElementById('modal-title');
    const modalCategory = document.getElementById('modal-category');
    const modalContent = document.getElementById('modal-content');
    
    if (modalIcon) {
        modalIcon.innerHTML = `<i class="${data.icon}"></i>`;
    }
    if (modalTitle) modalTitle.textContent = data.title;
    if (modalCategory) modalCategory.textContent = data.category;
    if (modalContent) modalContent.innerHTML = data.content;
    
    // Re-initialize Lucide icons for modal content
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
    
    // Open modal
    modal.classList.add('modal-open');
    document.body.style.overflow = 'hidden';
    
    // ESC key to close
    const escHandler = (e) => {
        if (e.key === 'Escape') {
            closeLoreModal();
            document.removeEventListener('keydown', escHandler);
        }
    };
    document.addEventListener('keydown', escHandler);
}

function closeLoreModal() {
    const modal = document.getElementById('lore-modal');
    if (!modal) return;
    
    modal.classList.remove('modal-open');
    document.body.style.overflow = '';
}

// Make functions globally available
window.openLoreModal = openLoreModal;
window.closeLoreModal = closeLoreModal;
