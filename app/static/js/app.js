// Chrome Isolation Manager - Frontend JavaScript

let profiles = [];

// Load profiles on page load
document.addEventListener('DOMContentLoaded', () => {
    refreshProfiles();
    // Auto-refresh every 5 seconds
    setInterval(refreshProfiles, 5000);
});

async function refreshProfiles() {
    try {
        const response = await fetch('/api/profiles');
        const data = await response.json();
        profiles = data.profiles;
        renderProfiles();
    } catch (error) {
        console.error('Error fetching profiles:', error);
        showError('Failed to load profiles');
    }
}

function renderProfiles() {
    const container = document.getElementById('profiles-container');

    if (profiles.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <h3>📭 No Profiles Yet</h3>
                <p>Create your first isolated Chrome profile to get started</p>
                <button class="btn btn-primary" onclick="showCreateModal()">
                    ➕ Create Profile
                </button>
            </div>
        `;
        return;
    }

    container.innerHTML = profiles.map(profile => `
        <div class="profile-card">
            <div class="profile-header">
                <div class="profile-name">
                    🌐 ${escapeHtml(profile.name)}
                </div>
                <span class="status-badge status-${profile.status}">
                    ${getStatusText(profile.status)}
                </span>
            </div>
            
            <div class="profile-info">
                <div>💾 Storage: ${profile.size_mb} MB</div>
                <div>🖥️ Desktop Entry: ${profile.has_desktop_entry ? '✅ Yes' : '❌ No'}</div>
            </div>
            
            <div class="profile-actions">
                ${profile.status === 'running'
            ? `<button class="btn btn-danger btn-sm" onclick="stopProfile('${escapeHtml(profile.name)}')">⏹️ Stop</button>`
            : `<button class="btn btn-success btn-sm" onclick="startProfile('${escapeHtml(profile.name)}')">▶️ Start</button>`
        }
                <button class="btn btn-danger btn-sm" onclick="deleteProfile('${escapeHtml(profile.name)}')">🗑️ Delete</button>
            </div>
        </div>
    `).join('');
}

function getStatusText(status) {
    const statusMap = {
        'running': '🟢 Running',
        'exited': '🔴 Stopped',
        'not_found': '⚪ Not Started'
    };
    return statusMap[status] || status;
}

function showCreateModal() {
    document.getElementById('createModal').style.display = 'block';
    document.getElementById('profileName').focus();
}

function closeCreateModal() {
    document.getElementById('createModal').style.display = 'none';
    document.getElementById('createForm').reset();
}

// Close modal when clicking outside
window.onclick = function (event) {
    const modal = document.getElementById('createModal');
    if (event.target === modal) {
        closeCreateModal();
    }
}

async function createProfile(event) {
    event.preventDefault();

    const profileName = document.getElementById('profileName').value.trim();
    const profileLocation = document.getElementById('profileLocation').value.trim();

    if (!profileName) {
        showError('Profile name is required');
        return;
    }

    try {
        showLoading(true);
        const requestBody = { name: profileName };

        // Add location if provided
        if (profileLocation) {
            requestBody.location = profileLocation;
        }

        const response = await fetch('/api/profiles', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        const data = await response.json();

        if (response.ok) {
            showSuccess(`Profile "${profileName}" created successfully!`);
            closeCreateModal();
            await refreshProfiles();
        } else {
            showError(data.error || 'Failed to create profile');
        }
    } catch (error) {
        console.error('Error creating profile:', error);
        showError('Failed to create profile');
    } finally {
        showLoading(false);
    }
}

async function startProfile(profileName) {
    try {
        showLoading(true);
        const response = await fetch(`/api/profiles/${encodeURIComponent(profileName)}/start`, {
            method: 'POST'
        });

        const data = await response.json();

        if (response.ok) {
            showSuccess(`Profile "${profileName}" started!`);
            await refreshProfiles();
        } else {
            showError(data.error || 'Failed to start profile');
        }
    } catch (error) {
        console.error('Error starting profile:', error);
        showError('Failed to start profile');
    } finally {
        showLoading(false);
    }
}

async function stopProfile(profileName) {
    try {
        showLoading(true);
        const response = await fetch(`/api/profiles/${encodeURIComponent(profileName)}/stop`, {
            method: 'POST'
        });

        const data = await response.json();

        if (response.ok) {
            showSuccess(`Profile "${profileName}" stopped!`);
            await refreshProfiles();
        } else {
            showError(data.error || 'Failed to stop profile');
        }
    } catch (error) {
        console.error('Error stopping profile:', error);
        showError('Failed to stop profile');
    } finally {
        showLoading(false);
    }
}

async function deleteProfile(profileName) {
    if (!confirm(`Are you sure you want to delete profile "${profileName}"?\n\nThis will remove all data and cannot be undone.`)) {
        return;
    }

    try {
        showLoading(true);
        const response = await fetch(`/api/profiles/${encodeURIComponent(profileName)}`, {
            method: 'DELETE'
        });

        const data = await response.json();

        if (response.ok) {
            showSuccess(`Profile "${profileName}" deleted!`);
            await refreshProfiles();
        } else {
            showError(data.error || 'Failed to delete profile');
        }
    } catch (error) {
        console.error('Error deleting profile:', error);
        showError('Failed to delete profile');
    } finally {
        showLoading(false);
    }
}

function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

function showToast(message, type = 'success') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const icon = type === 'success' ? '✅' : '❌';

    toast.innerHTML = `
        <span class="toast-icon">${icon}</span>
        <span class="toast-message">${escapeHtml(message)}</span>
        <span class="toast-close" onclick="this.parentElement.remove()">×</span>
    `;

    container.appendChild(toast);

    // Auto-remove after 4 seconds
    setTimeout(() => {
        toast.style.animation = 'slideOutRight 0.4s ease';
        setTimeout(() => toast.remove(), 400);
    }, 4000);
}

function showSuccess(message) {
    showToast(message, 'success');
}

function showError(message) {
    showToast(message, 'error');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
