/**
 * ppr-logger · script.js
 * ───────────────────────
 * NUI inspection card logic.
 *
 * - Receives 'open' message from Lua → builds data rows dynamically
 * - Clipboard: navigator.clipboard with execCommand fallback
 *   (NUI browser can be picky — the fallback is critical)
 * - ESC + close button → posts to the 'close' NUI callback
 *   so Lua can release focus (SetNuiFocus(false, false))
 */

const card      = document.getElementById('card');
const rowsEl    = document.getElementById('rows');
const badge     = document.getElementById('badge');
const timeBadge = document.getElementById('timeBadge');
let currentData = null;

// ═══════════════════════════════════════════════════════
//  CLIPBOARD (NUI-safe with fallback)
// ═══════════════════════════════════════════════════════

/**
 * Copies text to clipboard. Tries modern API first,
 * falls back to execCommand for older NUI browsers.
 * @param {string} text
 */
function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).catch(() => fallbackCopy(text));
    } else {
        fallbackCopy(text);
    }
}

/**
 * Fallback clipboard copy using a temporary textarea + execCommand.
 * @param {string} text
 */
function fallbackCopy(text) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    ta.style.top = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (_) {}
    ta.remove();
}

// ═══════════════════════════════════════════════════════
//  ROW BUILDER
// ═══════════════════════════════════════════════════════

/**
 * Creates a single data row: label | value | copy button.
 * @param {string} label   Row label (uppercase)
 * @param {string} value   Row value (monospace)
 */
function addRow(label, value) {
    const row = document.createElement('div');
    row.className = 'row';

    // Sanitize value to prevent XSS in NUI
    const safeValue = String(value || '—')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');

    row.innerHTML = `
        <span class="label">${label}</span>
        <span class="value" title="${safeValue}">${safeValue}</span>
        <button class="copy">Copy</button>
    `;

    // Copy button click handler
    const btn = row.querySelector('.copy');
    btn.addEventListener('click', () => {
        copyText(value || '');
        btn.textContent = '✓';
        btn.classList.add('done');
        setTimeout(() => {
            btn.textContent = 'Copy';
            btn.classList.remove('done');
        }, 1200);
    });

    rowsEl.appendChild(row);
}

// ═══════════════════════════════════════════════════════
//  MESSAGE HANDLER (from Lua SendNUIMessage)
// ═══════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || msg.action !== 'open' || !msg.data) return;

    const d = msg.data;
    currentData = d;

    // Update header
    document.getElementById('charName').textContent = d.charName || 'Unknown';
    document.getElementById('subInfo').textContent =
        `Left at ${d.leftAt || '??:??'} · Session: ${d.session || 'unknown'}`;

    // Badge styling
    if (d.isCombatLog) {
        badge.textContent = '⚠ COMBAT LOG';
        badge.className = 'badge combat-log';
        card.classList.add('combat-log');
    } else {
        badge.textContent = 'DISCONNECTED';
        badge.className = 'badge';
        card.classList.remove('combat-log');
    }

    // Time badge
    timeBadge.textContent = d.leftAt || '';

    // Build data rows
    rowsEl.innerHTML = '';
    addRow('Account', d.accName);
    addRow('Reason', d.reason);

    if (d.disconnectType) {
        addRow('Type', d.disconnectType.toUpperCase());
    }

    if (d.citizenId && d.citizenId !== 'N/A' && d.citizenId !== '') {
        addRow('Citizen ID', d.citizenId);
    }

    // Identifiers
    if (d.ids && typeof d.ids === 'object') {
        for (const [type, value] of Object.entries(d.ids)) {
            if (value) {
                addRow(type.toUpperCase(), value);
            }
        }
    }

    // Show card
    card.classList.remove('hidden');
});

// ═══════════════════════════════════════════════════════
//  COPY ALL
// ═══════════════════════════════════════════════════════

document.getElementById('copyAll').addEventListener('click', () => {
    if (!currentData) return;
    const d = currentData;

    let out = '';
    out += `Character: ${d.charName || 'Unknown'}\n`;
    out += `Account: ${d.accName || 'Unknown'}\n`;
    out += `Reason: ${d.reason || 'unknown'}\n`;
    out += `Session: ${d.session || 'unknown'}\n`;
    out += `Left At: ${d.leftAt || 'unknown'}\n`;

    if (d.disconnectType) {
        out += `Type: ${d.disconnectType}\n`;
    }
    if (d.isCombatLog) {
        out += `Combat Log: YES\n`;
    }

    if (d.ids && typeof d.ids === 'object') {
        for (const [type, value] of Object.entries(d.ids)) {
            if (value) out += `${type}: ${value}\n`;
        }
    }

    copyText(out.trim());

    // Visual feedback on button
    const btn = document.getElementById('copyAll');
    const original = btn.innerHTML;
    btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> Copied!`;
    setTimeout(() => { btn.innerHTML = original; }, 1500);
});

// ═══════════════════════════════════════════════════════
//  CLOSE (button + ESC)
// ═══════════════════════════════════════════════════════

function closeCard() {
    card.classList.add('hidden');
    card.classList.remove('combat-log');
    currentData = null;

    // Tell Lua to release NUI focus
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    }).catch(() => {}); // Silently handle fetch errors
}

document.getElementById('closeBtn').addEventListener('click', closeCard);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        e.preventDefault();
        closeCard();
    }
});
