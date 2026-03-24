/**
 * WayangOS Internationalization (i18n) Script
 * Supports EN (English) and ID (Indonesian)
 * Default: ID (Indonesian) — target market
 * Stored in localStorage as 'wayangos-lang'
 */

(function() {
    'use strict';

    function getLang() {
        var stored = localStorage.getItem('wayangos-lang');
        if (stored === 'en' || stored === 'id') return stored;
        // Detect browser language, fallback to ID
        var browserLang = (navigator.language || navigator.userLanguage || '').toLowerCase();
        return browserLang.startsWith('en') ? 'en' : 'id';
    }

    function setLang(lang) {
        localStorage.setItem('wayangos-lang', lang);
        applyLang(lang);
    }

    function applyLang(lang) {
        // Update all elements with data-en and data-id attributes
        var elements = document.querySelectorAll('[data-en][data-id]');
        for (var i = 0; i < elements.length; i++) {
            var el = elements[i];
            var text = el.getAttribute('data-' + lang);
            if (text !== null) {
                // Check if element has child elements we should preserve
                if (el.children.length === 0 || el.hasAttribute('data-i18n-html')) {
                    if (el.hasAttribute('data-i18n-html')) {
                        el.innerHTML = text;
                    } else {
                        el.textContent = text;
                    }
                } else {
                    // For elements with mixed content, only update text nodes
                    el.innerHTML = text;
                }
            }
        }

        // Update placeholder attributes
        var placeholders = document.querySelectorAll('[data-placeholder-en][data-placeholder-id]');
        for (var j = 0; j < placeholders.length; j++) {
            placeholders[j].placeholder = placeholders[j].getAttribute('data-placeholder-' + lang);
        }

        // Update button states
        var btnEn = document.getElementById('btn-en');
        var btnId = document.getElementById('btn-id');
        if (btnEn && btnId) {
            btnEn.style.background = lang === 'en' ? 'var(--accent, #c8941a)' : 'transparent';
            btnEn.style.color = lang === 'en' ? '#000' : 'var(--text-secondary, #a09070)';
            btnEn.style.border = lang === 'en' ? '1px solid var(--accent, #c8941a)' : '1px solid var(--border, #2e2318)';
            btnId.style.background = lang === 'id' ? 'var(--accent, #c8941a)' : 'transparent';
            btnId.style.color = lang === 'id' ? '#000' : 'var(--text-secondary, #a09070)';
            btnId.style.border = lang === 'id' ? '1px solid var(--accent, #c8941a)' : '1px solid var(--border, #2e2318)';
        }
    }

    // Expose globally
    window.setLang = setLang;
    window.getLang = getLang;

    // Apply on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() { applyLang(getLang()); });
    } else {
        applyLang(getLang());
    }
})();
