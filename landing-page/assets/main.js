/**
 * WayangOS — Shared JavaScript
 * Nav toggle, WhatsApp button behavior, common utilities
 */

(function() {
  'use strict';

  // Mobile nav toggle
  var toggle = document.querySelector('.nav-toggle');
  var links = document.querySelector('.nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function() {
      links.classList.toggle('active');
    });
    // Close nav on link click (mobile)
    var navAnchors = links.querySelectorAll('a');
    for (var i = 0; i < navAnchors.length; i++) {
      navAnchors[i].addEventListener('click', function() {
        links.classList.remove('active');
      });
    }
  }
})();
