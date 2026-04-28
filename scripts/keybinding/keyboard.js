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
let activeKeys = new Set(); // Currently pressed/toggled keys (normalized)
let hoveredKeyboardKeys = new Set(); // Temporary keys from hovering keyboard tiles
let hoveredBindingKeys = new Set(); // Temporary keys from hovering binding rows
let searchQuery = "";
const HOVER_CLEAR_DELAY_MS = 120;

let keyboardHoverClearTimers = new Map();
let bindingHoverClearTimer = null;

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
        const response = await fetch('keybindings.json');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        bindings = data.bindings || [];
        console.log(`Loaded ${bindings.length} keybindings`);
    } catch (e) {
        console.error("Failed to load keybindings.json", e);
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
        const token = normalizeKeyToken(keyName);
        if (token) {
            if (activeKeys.has(token)) {
                activeKeys.delete(token);
            } else {
                activeKeys.add(token);
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
        activeKeys.clear();
        searchInputEl.value = '';
        searchQuery = '';
        updateUI();
    });
}

function handleKeyDown(e) {
    const token = normalizeKeyToken(e.key);
    if (token) {
        activeKeys.add(token);
        updateUI();
    }

    if (e.key === 'Escape') {
        activeKeys.clear();
        searchInputEl.value = '';
        searchQuery = '';
        updateUI();
    }
}

function handleKeyUp(e) {
    const token = normalizeKeyToken(e.key);
    if (token) {
        activeKeys.delete(token);
        updateUI();
    }
}

function normalizeKeyToken(key) {
    if (!key) return null;

    const raw = String(key).trim();
    if (!raw) return null;

    const aliasMap = {
        'Shift': 'SHIFT',
        'ShiftLeft': 'SHIFT',
        'ShiftRight': 'SHIFT',
        'Control': 'CTRL',
        'Ctrl': 'CTRL',
        'CtrlLeft': 'CTRL',
        'CtrlRight': 'CTRL',
        'Alt': 'ALT',
        'AltLeft': 'ALT',
        'AltRight': 'ALT',
        'Meta': 'SUPER',
        'OS': 'SUPER',
        'Super': 'SUPER',
        'Win': 'SUPER',
        'WinLeft': 'SUPER',
        'WinRight': 'SUPER',
        'Escape': 'ESC',
        'Esc': 'ESC',
        'Enter': 'ENTER',
        'Backspace': 'BACKSPACE',
        'Tab': 'TAB',
        'Space': 'SPACE',
        ' ': 'SPACE',
        'ArrowUp': 'UP',
        'ArrowDown': 'DOWN',
        'ArrowLeft': 'LEFT',
        'ArrowRight': 'RIGHT'
    };

    if (aliasMap[raw]) return aliasMap[raw];

    if (raw.length === 1) {
        return raw.toUpperCase();
    }

    return raw.toUpperCase();
}

function getBindingKeySet(binding) {
    const keys = new Set();
    (binding.mods || []).forEach(mod => {
        const token = normalizeKeyToken(mod);
        if (token) keys.add(token);
    });

    const keyToken = normalizeKeyToken(binding.key);
    if (keyToken) keys.add(keyToken);

    return keys;
}

function matchesActiveKeys(binding) {
    const filterKeys = getFilterKeys();
    if (filterKeys.size === 0) return true;

    const bindingKeys = getBindingKeySet(binding);
    return [...filterKeys].every(key => bindingKeys.has(key));
}

function getFilterKeys() {
    return new Set([...activeKeys, ...hoveredKeyboardKeys]);
}

function formatKeyForCombo(key) {
    const token = normalizeKeyToken(key);
    const display = {
        SUPER: 'SUPER',
        SHIFT: 'SHIFT',
        CTRL: 'CTRL',
        ALT: 'ALT',
        ENTER: 'ENTER',
        RETURN: 'RETURN',
        ESC: 'ESC',
        TAB: 'TAB',
        SPACE: 'SPACE',
        LEFT: 'LEFT',
        RIGHT: 'RIGHT',
        UP: 'UP',
        DOWN: 'DOWN',
        BACKSPACE: 'BACKSPACE'
    };

    if (!token) return '';
    return display[token] || token;
}

function formatBindingCombo(binding) {
    const mods = (binding.mods || []).map(formatKeyForCombo).filter(Boolean);
    const key = formatKeyForCombo(binding.key);
    return [...mods, key].filter(Boolean).join('+') || '(no combo)';
}

function renderKeyboard() {
    // Clear existing
    keyboardEl.innerHTML = '';

    KEYBOARD_LAYOUT.forEach(row => {
        const rowDiv = document.createElement('div');
        rowDiv.className = 'mb-1 flex min-w-[400px] gap-0.5 min-[600px]:mb-1.5 min-[600px]:gap-1 sm:mb-2';

        row.forEach(keyLabel => {
            const keyEl = document.createElement('div');
            keyEl.className = 'key box-border flex-1 cursor-pointer select-none border border-[#353543] bg-[#0d0d14]/90 px-0.5 py-0.5 text-center text-[8px] leading-[1.05] text-[#f0dbcf] transition-colors duration-150 min-[600px]:px-1 min-[600px]:py-1 min-[600px]:text-[10px] min-[600px]:leading-tight sm:px-1 sm:py-1 sm:text-[10px] md:px-1.5 md:py-1.5 md:text-xs lg:px-2 lg:py-2 lg:text-sm';
            keyEl.dataset.key = keyLabel;
            keyEl.textContent = getDisplayLabel(keyLabel);

            keyEl.addEventListener('mouseenter', () => {
                const token = normalizeKeyToken(keyLabel);
                if (!token) return;
                const pendingTimer = keyboardHoverClearTimers.get(token);
                if (pendingTimer) {
                    clearTimeout(pendingTimer);
                    keyboardHoverClearTimers.delete(token);
                }
                hoveredKeyboardKeys.add(token);
                updateUI();
            });

            keyEl.addEventListener('mouseleave', () => {
                const token = normalizeKeyToken(keyLabel);
                if (!token) return;
                const timer = setTimeout(() => {
                    hoveredKeyboardKeys.delete(token);
                    keyboardHoverClearTimers.delete(token);
                    updateUI();
                }, HOVER_CLEAR_DELAY_MS);
                keyboardHoverClearTimers.set(token, timer);
            });

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

function getKeyActiveClasses(keyToken) {
    const modifierStyles = {
        SUPER: ['bg-[#DD5C5C]', 'text-[#07070B]'],
        ALT: ['bg-[#D7A88D]', 'text-[#07070B]'],
        SHIFT: ['bg-[#c09dc8]', 'text-[#07070B]'],
        CTRL: ['bg-[#9cab8d]', 'text-[#07070B]']
    };

    return modifierStyles[keyToken] || ['bg-[#b4b691]', 'text-[#07070B]'];
}

function getKeyModifiers(keyLabel) {
    // Return which modifier categories this key belongs to
    const key = normalizeKeyToken(KEY_ALIASES[keyLabel] || keyLabel);
    switch (key) {
        case 'SUPER': return ['SUPER'];
        case 'ALT': return ['ALT'];
        case 'CTRL': return ['CTRL'];
        case 'SHIFT': return ['SHIFT'];
        default: return [];
    }
}

function updateUI() {
    updateClearButtonState();
    updateKeyboardHighlight();
    renderBindings();
}

function updateClearButtonState() {
    if (!clearButtonEl) return;
    clearButtonEl.classList.toggle('is-active', activeKeys.size > 0 || searchQuery.length > 0);
}

function updateKeyboardHighlight() {
    document.querySelectorAll('.key').forEach(keyEl => {
        keyEl.classList.remove(
            'bg-[#b4b691]',
            'bg-[#DD5C5C]',
            'bg-[#D7A88D]',
            'bg-[#c09dc8]',
            'bg-[#9cab8d]',
            'bg-[#353543]',
            'text-[#07070B]',
            'text-[#f0dbcf]'
        );

        const keyToken = normalizeKeyToken(keyEl.dataset.key);
        const isPressedOrHovered = keyToken
            ? (activeKeys.has(keyToken) || hoveredKeyboardKeys.has(keyToken) || hoveredBindingKeys.has(keyToken))
            : false;
        if (isPressedOrHovered) {
            keyEl.classList.add(...getKeyActiveClasses(keyToken));
        }

        // Check if this key appears in any currently visible binding
        const keyInFilteredBindings = bindings.some(b => {
            if (!matchesActiveKeys(b)) return false;

            // Check if this binding's key matches this visual key
            const bindingKeys = getBindingKeySet(b);
            const visualToken = normalizeKeyToken(keyEl.dataset.key);
            return visualToken ? bindingKeys.has(visualToken) : false;
        });

        if (keyInFilteredBindings && !isPressedOrHovered) {
            keyEl.classList.add('bg-[#353543]');
        }
    });
}

function renderBindings() {
    const filtered = bindings.filter(binding => {
        if (!matchesActiveKeys(binding)) return false;

        // Check search query
        if (searchQuery && 
            !(binding.description || '').toLowerCase().includes(searchQuery) &&
            !(binding.dispatcher || '').toLowerCase().includes(searchQuery) &&
            !(binding.combo || '').toLowerCase().includes(searchQuery)) {
            return false;
        }

        return true;
    });

    bindingsListEl.innerHTML = '';
    if (filtered.length === 0) {
        bindingsListEl.innerHTML = '<p class="px-3 py-3 text-sm text-[#9a9dbc]">No matching keybindings</p>';
        return;
    }

    filtered.forEach(b => {
        const div = document.createElement('div');
        div.className = 'binding-item flex items-center gap-3 border-b border-[#2a2a35] px-2 py-1.5 text-sm last:border-b-0 hover:bg-[#12121a]';
        const combo = formatBindingCombo(b);

        div.addEventListener('mouseenter', () => {
            if (bindingHoverClearTimer) {
                clearTimeout(bindingHoverClearTimer);
                bindingHoverClearTimer = null;
            }
            hoveredBindingKeys = getBindingKeySet(b);
            updateKeyboardHighlight();
        });

        div.addEventListener('mouseleave', () => {
            bindingHoverClearTimer = setTimeout(() => {
                hoveredBindingKeys.clear();
                bindingHoverClearTimer = null;
                updateKeyboardHighlight();
            }, HOVER_CLEAR_DELAY_MS);
        });

        div.innerHTML = `
            <span class="combo min-w-[12rem] font-mono text-xs text-[#d7a88d]">${combo}</span>
            <span class="description flex-1 truncate text-[#f0dbcf]">${b.description || ''}</span>
            <small class="dispatcher shrink-0 text-xs uppercase tracking-wide text-[#9a9dbc]">${b.dispatcher || ''}</small>
        `;
        bindingsListEl.appendChild(div);
    });

    // Update header count
    const bindingsHeader = document.getElementById('bindings-header');
    if (bindingsHeader) {
        bindingsHeader.textContent = `Keybindings (${filtered.length}/${bindings.length})`;
    }
}
