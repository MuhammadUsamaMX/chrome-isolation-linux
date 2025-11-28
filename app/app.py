"""
Chrome Isolation Manager - Main Flask Application
"""
from flask import Flask, render_template, jsonify, request
import os
import shutil
from docker_manager import DockerManager
from desktop_manager import DesktopManager
from config import HOST, PORT, DEBUG, CHROME_PROFILES_DIR

app = Flask(__name__)

# Get the launcher script path
LAUNCHER_SCRIPT = os.path.join(os.path.dirname(os.path.dirname(__file__)), 
                               'scripts', 'chrome-launcher.sh')

docker_mgr = DockerManager()
desktop_mgr = DesktopManager(LAUNCHER_SCRIPT)

@app.route('/')
def index():
    """Main dashboard"""
    return render_template('index.html')

@app.route('/api/profiles', methods=['GET'])
def list_profiles():
    """List all profiles"""
    profiles = []
    
    if os.path.exists(CHROME_PROFILES_DIR):
        for profile_name in os.listdir(CHROME_PROFILES_DIR):
            profile_path = os.path.join(CHROME_PROFILES_DIR, profile_name)
            if os.path.isdir(profile_path):
                profiles.append({
                    'name': profile_name,
                    'status': docker_mgr.container_status(profile_name),
                    'size_mb': docker_mgr.get_profile_size(profile_name),
                    'has_desktop_entry': desktop_mgr.desktop_entry_exists(profile_name)
                })
    
    return jsonify({'profiles': profiles})

@app.route('/api/profiles', methods=['POST'])
def create_profile():
    """Create a new profile"""
    data = request.json
    profile_name = data.get('name', '').strip()
    custom_location = data.get('location', '').strip()
    
    if not profile_name:
        return jsonify({'error': 'Profile name is required'}), 400
    
    # Validate profile name (alphanumeric, dash, underscore only)
    if not all(c.isalnum() or c in '-_' for c in profile_name):
        return jsonify({'error': 'Invalid profile name. Use only letters, numbers, dash, and underscore'}), 400
    
    # Determine profile directory
    if custom_location:
        # Use custom location if provided
        profile_dir = os.path.expanduser(custom_location)
        if not os.path.isabs(profile_dir):
            profile_dir = os.path.abspath(profile_dir)
    else:
        # Use default location
        profile_dir = docker_mgr.get_profile_dir(profile_name)
    
    if os.path.exists(profile_dir):
        return jsonify({'error': 'Profile directory already exists'}), 400
    
    # Create profile directory
    os.makedirs(profile_dir, exist_ok=True)
    os.makedirs(os.path.join(profile_dir, 'Downloads'), exist_ok=True)
    
    # Create desktop entry
    desktop_mgr.create_desktop_entry(profile_name)
    
    return jsonify({
        'status': 'created',
        'name': profile_name,
        'path': profile_dir
    })

@app.route('/api/profiles/<profile_name>', methods=['DELETE'])
def delete_profile(profile_name):
    """Delete a profile"""
    # Stop and remove container if exists
    docker_mgr.stop_container(profile_name)
    docker_mgr.remove_container(profile_name)
    
    # Remove desktop entry
    desktop_mgr.remove_desktop_entry(profile_name)
    
    # Remove profile directory
    profile_dir = docker_mgr.get_profile_dir(profile_name)
    if os.path.exists(profile_dir):
        shutil.rmtree(profile_dir)
    
    return jsonify({'status': 'deleted', 'name': profile_name})

@app.route('/api/profiles/<profile_name>/start', methods=['POST'])
def start_profile(profile_name):
    """Start a profile container"""
    result = docker_mgr.start_container(profile_name)
    return jsonify(result)

@app.route('/api/profiles/<profile_name>/stop', methods=['POST'])
def stop_profile(profile_name):
    """Stop a profile container"""
    result = docker_mgr.stop_container(profile_name)
    return jsonify(result)

@app.route('/api/profiles/<profile_name>/status', methods=['GET'])
def profile_status(profile_name):
    """Get profile status"""
    return jsonify({
        'name': profile_name,
        'status': docker_mgr.container_status(profile_name),
        'size_mb': docker_mgr.get_profile_size(profile_name)
    })

if __name__ == '__main__':
    print(f"🚀 Chrome Isolation Manager starting on http://{HOST}:{PORT}")
    print(f"📁 Profiles directory: {CHROME_PROFILES_DIR}")
    app.run(host=HOST, port=PORT, debug=DEBUG)
