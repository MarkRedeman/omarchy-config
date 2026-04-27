// Keybinding Visualizer - Main Logic

// Standard US ANSI keyboard layout (rows from top to bottom)
const KEYBOARD_LAYOUT = [
    ["Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
    ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace"],
    ["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
    ["CapsLock", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Enter"],
    ["ShiftLeft", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "ShiftRight"],
    ["CtrlLeft", "WinLeft", "AltLeft", "Space", "AltRight", "WinRight", "Menu", "CtrlRight"]
];

// Key alias mapping for matching against Hyprland bindings
const KEY_ALIASES = {
    // Modifiers
    "WinLeft": "SUPER",
    "WinRight": "SUPER",
    "AltLeft": "ALT",
    "AltRight": "ALT",
    "CtrlLeft": "CTRL",
    "CtrlRight": "CTRL",
    "ShiftLeft": "SHIFT",
    "ShiftRight": "SHIFT",
    // Special keys
    "Enter": "ENTER",
    "Escape": "ESC",
    "Backspace": "BACKSPACE",
    "Tab": "TAB",
    "Space": "SPACE",
    "CapsLock": "CAPSLOCK",
    // Arrow keys and others
    "ArrowUp": "UP",
    "ArrowDown": "DOWN",
    "ArrowLeft": "LEFT",
    "ArrowRight": "RIGHT",
    // Numpad etc. not needed for modifier visualization
};

// Reverse mapping for display
const DISPLAY_ALIASES = {
    "SUPER": "WIN",
    "CTRL": "CTRL",
    "ALT": "ALT",
    "SHIFT": "SHIFT",
    // Add others as needed
};

// State
let bindings = [];
let activeMods = new Set(); // Currently pressed modifier keys (SUPER, SHIFT, etc.)
let searchQuery = "";

// DOM elements
let keyboardEl, bindingsListEl, searchInputEl, clearButtonEl;

// Initialize
document.addEventListener('DOMContentLoaded', init);

async function init() {
    // Get DOM references
    keyboardEl = document.getElementById('keyboard');
    bindingsListEl = document.getElementById('bindings-list');
    searchInputEl = document.getElementById('search');
    clearButtonEl = document.getElementById('clear');

    // Load bindings
    await loadBindings();

    // Render keyboard
    renderKeyboard();

    // Render initial bindings list
    renderBindings();

    // Set up event listeners
    setupEventListeners();
}

async function loadBindings() {
    try {
        const response = fetch('keybindings.json');
        const data = await response.json();
        bindings = data.bindings || [];
        console.log(`Loaded ${bindings.length} keybindings`);
    } catch (err) {
        console.error("Failed to load keybindings.json", err);
        bindings = [];
    }
}

function setupEventListeners() {
    // Keyboard events for live key tracking
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    // Click on keyboard keys to toggle selection (fallback)
    keyboardEl.addEventListener('click', e => {
        const keyEl = e.target.closest('.key');
        if (!keyEl) return;
        const keyName = keyEl.dataset.key;
        if (!keyName) return;
        // Toggle modifier state for visualization
        const mod = keyToModifier(keyName);
        if (mod) {
            if (activeMods.has(mod)) {
                activeMods.delete(mod);
            } else {
                activeMods.add(mod);
            }
            updateUI();
        }
    });

    // Search input
    searchInputEl.addEventListener('input', e => {
        searchQuery = e.target.value.toLowerCase();
        renderBindings();
    });

    // Clear button
    clearButtonEl.addEventListener('click', () => {
        activeMods.clear();
        searchInputEl.value = '';
        searchQuery = '';
        updateUI();
    });
}

function handleKeyDown(e) {
    const mod = keyToModifier(e.key);
    if (mod) {
        activeMods.add(mod);
        updateUI();
    }
    // Also handle special keys like Escape for clearing?
    if (e.key === 'Escape') {
        activeMods.clear();
        searchInputEl.value = '';
        searchQuery = '';
        updateUI();
    }
}

function handleKeyUp(e) {
    const mod = keyToModifier(e.key);
    if (mod) {
        activeMods.delete(mod);
        updateUI();
    }
}

function keyToModifier(key) {
    // Map browser key names to our modifier names
    const map = {
        'Shift': 'SHIFT',
        'Control': 'CTRL',
        'Alt': 'ALT',
        'Meta': 'SUPER', // Cmd on Mac, Win on Windows/Linux
        'OS': 'SUPER',   // Firefox
        'Win': 'SUPER',
        'Super': 'SUPER'
    };
    return map[key] || null;
}

function renderKeyboard() {
    // Clear existing
    keyboardEl.innerHTML = '';

    KEYBOARD_LAYOUT.forEach(row => {
        const rowDiv = document.createElement('div');
        rowDiv.style.display = 'flex';
        rowDiv.style.gap = '4px';

        row.forEach(keyLabel => {
            const keyEl = document.createElement('div');
            keyEl.className = 'key';
            keyEl.dataset.key = keyLabel;
            keyEl.textContent = getDisplayLabel(keyLabel);

            // Store aliases for matching
            const mods = getKeyModifiers(keyLabel);
            if (mods.length > 0) {
                keyEl.dataset.mods = mods.join(' ');
            }

            rowDiv.appendChild(keyEl);
        });

        keyboardEl.appendChild(rowDiv);
    });
}

function getDisplayLabel(keyLabel) {
    // Map internal labels to display strings
    const map = {
        'WinLeft': 'WIN',
        'WinRight': 'WIN',
        'AltLeft': 'ALT',
        'AltRight': 'ALT',
        'CtrlLeft': 'CTRL',
        'CtrlRight': 'CTRL',
        'ShiftLeft': 'SHIFT',
        'ShiftRight': 'SHIFT',
        'CapsLock': 'CAPS',
        'Enter': '↵',
        'Backspace': '⌫',
        'Tab': '⇥',
        'Esc': 'Esc',
        'Space': '␣',
        'Menu': 'Menu',
        'F1': 'F1', 'F2': 'F2', 'F3': 'F3', 'F4': 'F4',
        'F5': 'F5', 'F6': 'F6', 'F7': 'F7', 'F8': 'F8',
        'F9': 'F9', 'F10': 'F10', 'F11': 'F11', 'F12': 'F12',
        '`': '`', '-': '-', '=': '=', '[': '[', ']': ']', '\\': '\\',
        ';': ';', "'": "'", ',': ',', '.': '.', '/': '/'
    };
    return map[keyLabel] || keyLabel;
}

function getKeyModifiers(keyLabel) {
    // Return which modifier categories this key belongs to
    const key = KEY_ALIASES[keyLabel] || keyLabel;
    switch (key) {
        case 'SUPER': return ['SUPER'];
        case 'ALT': return ['ALT'];
        case 'CTRL': return ['CTRL'];
        case 'SHIFT': return ['SHIFT'];
        default: return [];
    }
}

function updateUI() {
    updateKeyboardHighlight();
    renderBindings();
}

function updateKeyboardHighlight() {
    document.querySelectorAll('.key').forEach(keyEl => {
        keyEl.classList.remove('pressed', 'filter-match');

        const mods = keyEl.dataset.mods ? keyEl.dataset.mods.split(' ') : [];
        const isPressed = mods.some(m => activeMods.has(m));
        if (isPressed) {
            keyEl.classList.add('pressed');
        }

        // Check if this key appears in any currently visible binding
        const keyInFilteredBindings = bindings.some(b => {
            // Check if binding matches current mods (all active mods must be in binding)
            const bindingMods = new Set(b.mods);
            const modsMatch = [...activeMods].every(mod => bindingMods.has(mod));
            if (!modsMatch) return false;

            // Check if this binding's key matches this visual key
            const bindingKey = b.key;
            const displayKey = getDisplayLabel(keyEl.dataset.key);
            // Simplified: just check if the key label matches
            return bindingKey === keyEl.dataset.key ||
                   (bindingKey === 'SPACE' && keyEl.dataset.key === 'Space') ||
                   (bindingKey === 'ENTER' && keyEl.dataset.key === 'Enter') ||
                   (bindingKey === 'ESC' && keyEl.dataset.key === 'Esc') ||
                   (bindingKey === 'BACKSPACE' && keyEl.dataset.key === 'Backspace') ||
                   (bindingKey === 'TAB' && keyEl.dataset.key === 'Tab');
        });

        if (keyInFilteredBindings) {
            keyEl.classList.add('filter-match');
        }
    });
}

function renderBindings() {
    const filtered = bindings.filter(binding => {
        // 1. Check modifier requirements
        const bindingMods = new Set(binding.mods);
        const modsMatch = [...activeMods].every(mod => bindingMods.has(mod));
        if (!modsMatch) return false;

        // 2. Check search query
        if (searchQuery && 
            !binding.description.toLowerCase().includes(searchQuery) &&
            !binding.dispatcher.toLowerCase().includes(searchQuery) &&
            !binding.combo.toLowerCase().includes(searchQuery)) {
            return false;
        }

        return true;
    });

    bindingsListEl.innerHTML = '';
    if (filtered.length === 0) {
        bindingsListEl.innerHTML = '<p class="empty">No matching keybindings</p>';
        return;
    }

    filtered.forEach(b => {
        const div = document.createElement('div');
        div.className = 'binding-item';
        div.innerHTML = `
            <span class="combo">${b.combo || '(no combo)'}</span>
            <span class="description">${b.description}</span>
            <small class="dispatcher">${b.dispatcher}</small>
        `;
        bindingsListEl.appendChild(div);
    });

    // Update header count
    const bindingsHeader = document.querySelector('#bindings h2');
    if (bindingsHeader) {
        bindingsHeader.textContent = `Keybindings (${filtered.length}/${bindings.length})`;
    }
}