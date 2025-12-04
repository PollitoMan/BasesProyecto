
async function apiRequest(url, method = 'GET', data = null) {
    const options = {
        method: method,
        headers: {
            'Content-Type': 'application/json',
        }
    };

    if (data) {
        options.body = JSON.stringify(data);
    }

    try {
        const response = await fetch(url, options);
        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.error || 'Request failed');
        }

        return result;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

function showNotification(message, type = 'info') {
    const alertClass = `alert-${type}`;
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert ${alertClass}`;
    alertDiv.textContent = message;
    alertDiv.style.position = 'fixed';
    alertDiv.style.top = '20px';
    alertDiv.style.right = '20px';
    alertDiv.style.zIndex = '9999';
    alertDiv.style.minWidth = '300px';
    alertDiv.style.animation = 'fadeIn 0.3s ease-out';

    document.body.appendChild(alertDiv);

    setTimeout(() => {
        alertDiv.style.animation = 'fadeOut 0.3s ease-out';
        setTimeout(() => alertDiv.remove(), 300);
    }, 3000);
}

async function playTrack(trackId, albumId) {
    try {
        const result = await apiRequest('/api/play', 'POST', {
            track_id: trackId,
            album_id: albumId
        });

        console.log('Track play logged:', result);

    } catch (error) {
        console.error('Error logging play:', error);
    }
}

async function submitReview(albumId, rating = null, reviewText = '', reviewId = null, version = null) {
    try {
        const data = {
            album_id: albumId,
            review_text: reviewText
        };

        if (typeof rating === 'number') {
            data.rating = rating;
        }

        let url = '/api/review';
        let method = 'POST';

        if (reviewId) {
            url = `/api/review/${reviewId}`;
            method = 'PUT';
            data.version = version;
        }

        const result = await apiRequest(url, method, data);
        showNotification(result.message, 'success');

        setTimeout(() => location.reload(), 1000);

        return result;
    } catch (error) {
        showNotification(error.message, 'error');
        throw error;
    }
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

function initializeSearch() {
    const searchInput = document.querySelector('.search-bar input');
    if (searchInput) {
        const debouncedSearch = debounce((value) => {
            if (value.length >= 2) {
                window.location.href = `/?search=${encodeURIComponent(value)}`;
            }
        }, 500);

        searchInput.addEventListener('input', (e) => {
            debouncedSearch(e.target.value);
        });
    }
}

async function loadStatistics() {
    try {
        const stats = await apiRequest('/api/statistics');

        const elements = {
            'stat-albums': stats.total_albums || 0,
            'stat-reviews': stats.total_reviews || 0,
            'stat-users': stats.total_users || 0,
            'stat-rating': (stats.avg_rating || 0).toFixed(1)
        };

        for (const [id, value] of Object.entries(elements)) {
            const element = document.getElementById(id);
            if (element) {
                animateValue(element, 0, value, 1000);
            }
        }
    } catch (error) {
        console.error('Error loading statistics:', error);
    }
}

function animateValue(element, start, end, duration) {
    const isDecimal = end.toString().includes('.');
    const startTime = performance.now();

    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        const current = start + (end - start) * progress;
        element.textContent = isDecimal ? current.toFixed(1) : Math.floor(current);

        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }

    requestAnimationFrame(update);
}

function initializeRatingStars() {
    const ratingInputs = document.querySelectorAll('.rating-input');

    ratingInputs.forEach(ratingInput => {
        const labels = ratingInput.querySelectorAll('label');

        labels.forEach((label, index) => {
            label.addEventListener('mouseenter', () => {
                highlightStars(labels, labels.length - index);
            });
        });

        ratingInput.addEventListener('mouseleave', () => {
            const checked = ratingInput.querySelector('input:checked');
            if (checked) {
                const checkedIndex = Array.from(ratingInput.querySelectorAll('input'))
                    .indexOf(checked);
                highlightStars(labels, labels.length - checkedIndex);
            } else {
                highlightStars(labels, 0);
            }
        });
    });
}

function initializeTrackRatingInputs() {
    const groups = document.querySelectorAll('.track-rating-input');
    groups.forEach(group => {
        const buttons = Array.from(group.querySelectorAll('.track-rate-star'));
        buttons.forEach((btn, idx) => {
            btn.addEventListener('mouseenter', (e) => {
                buttons.forEach((b, i) => {
                    if (i <= idx) b.style.color = 'var(--spotify-green)';
                    else b.style.color = 'var(--spotify-gray)';
                });
            });

            btn.addEventListener('mouseleave', (e) => {

                buttons.forEach((b, i) => {
                    if (b.classList.contains('active')) b.style.color = 'var(--spotify-green)';
                    else b.style.color = 'var(--spotify-gray)';
                });
            });
        });
    });
}

function attachTrackStarClickHandlers() {
    const starButtons = document.querySelectorAll('.track-rate-star');
    starButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();

            const group = btn.closest('.track-user-rating');
            if (!group) return;
            const trackId = parseInt(group.dataset.trackId, 10);
            const albumId = parseInt(group.dataset.albumId || document.getElementById('album-id')?.value, 10);
            const value = parseInt(btn.dataset.value, 10);
            if (!trackId || !albumId || !value) return;

            try {
                setTrackRating(e, trackId, albumId, value);
            } catch (err) {
                console.error('Error calling setTrackRating:', err);
            }
        });
    });
}

function highlightStars(labels, count) {
    labels.forEach((label, index) => {
        if (index < count) {
            label.style.color = 'var(--spotify-green)';
        } else {
            label.style.color = 'var(--spotify-gray)';
        }
    });
}

async function triggerBackup() {
    if (!confirm('Are you sure you want to trigger a manual backup?')) {
        return;
    }

    try {
        showNotification('Backup started...', 'info');
        const result = await apiRequest('/api/backup', 'POST');
        showNotification('Backup completed successfully!', 'success');
        console.log('Backup results:', result);
    } catch (error) {
        showNotification('Backup failed: ' + error.message, 'error');
    }
}

function initializeKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {

        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            const searchInput = document.querySelector('.search-bar input');
            if (searchInput) {
                searchInput.focus();
            }
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    console.log('🎵 Music Reviews Platform initialized');

    initializeSearch();
    initializeRatingStars();
    initializeTrackRatingInputs();
        attachTrackStarClickHandlers();
    initializeKeyboardShortcuts();

    if (document.getElementById('stats-container')) {
        loadStatistics();
    }

    const cards = document.querySelectorAll('.album-card, .review-card');
    cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 0.05}s`;
        card.classList.add('fade-in');
    });
});

window.MusicReviews = {
    playTrack,
    submitReview,
    triggerBackup,
    showNotification
};

