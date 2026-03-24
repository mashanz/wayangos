// Lightbox — shared across all app pages
(function() {
    var lbImages = [];
    var lbIndex = 0;
    var lb, lbImg, lbCounter;
    var touchStartX = 0;
    var touchEndX = 0;

    function init() {
        lb = document.getElementById('lightbox');
        lbImg = document.getElementById('lb-img');
        lbCounter = document.getElementById('lb-counter');
        if (!lb) return;

        // Collect all gallery images
        var items = document.querySelectorAll('.gallery-item');
        lbImages = [];
        items.forEach(function(item, i) {
            var img = item.querySelector('img');
            if (img) lbImages.push(img.src);
            item.addEventListener('click', function() { openLightbox(i); });
        });

        // Keyboard
        document.addEventListener('keydown', function(e) {
            if (!lb.classList.contains('active')) return;
            if (e.key === 'Escape') closeLightbox();
            else if (e.key === 'ArrowLeft') navLightbox(-1);
            else if (e.key === 'ArrowRight') navLightbox(1);
        });

        // Touch swipe disabled — conflicts with pinch-to-zoom on detail images

        // Close button
        var closeBtn = lb.querySelector('.lb-close');
        if (closeBtn) {
            closeBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                closeLightbox();
            });
        }

        // Prev/Next buttons
        var prevBtn = lb.querySelector('.lb-prev');
        var nextBtn = lb.querySelector('.lb-next');
        if (prevBtn) {
            prevBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                navLightbox(-1);
            });
        }
        if (nextBtn) {
            nextBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                navLightbox(1);
            });
        }

        // Click overlay to close (but not on image or controls)
        lb.addEventListener('click', function(e) {
            if (e.target === lb) closeLightbox();
        });

        // Mobile tap zones (left/right thirds of image)
        lbImg.addEventListener('click', function(e) {
            e.stopPropagation();
            var rect = lbImg.getBoundingClientRect();
            var x = e.clientX - rect.left;
            if (x < rect.width / 3) navLightbox(-1);
            else if (x > rect.width * 2/3) navLightbox(1);
            // middle third does nothing
        });
    }

    function openLightbox(index) {
        if (!lb || lbImages.length === 0) return;
        lbIndex = index;
        lbImg.src = lbImages[lbIndex];
        lbCounter.textContent = (lbIndex + 1) + ' / ' + lbImages.length;
        lb.classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    function closeLightbox() {
        if (!lb) return;
        lb.classList.remove('active');
        document.body.style.overflow = '';
    }

    function navLightbox(dir) {
        if (lbImages.length === 0) return;
        lbIndex = (lbIndex + dir + lbImages.length) % lbImages.length;
        lbImg.src = lbImages[lbIndex];
        lbCounter.textContent = (lbIndex + 1) + ' / ' + lbImages.length;
    }

    // Expose globally
    window.openLightbox = openLightbox;
    window.closeLightbox = closeLightbox;
    window.navLightbox = navLightbox;

    // Init on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
