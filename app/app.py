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

@app.route('/api/profiles/<profile_name>/export', methods=['GET'])
def export_profile(profile_name):
    """Export profile as zip archive"""
    import zipfile
    import tempfile
    from flask import send_file
    
    profile_dir = docker_mgr.get_profile_dir(profile_name)
    if not os.path.exists(profile_dir):
        return jsonify({'error': 'Profile not found'}), 404
    
    # Create temporary zip file
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.zip')
    
    try:
        with zipfile.ZipFile(temp_file.name, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Walk through the directory and add files to zip
            for root, dirs, files in os.walk(profile_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    # Calculate arcname (relative path inside zip)
                    # We want the profile_name as the root folder in the zip
                    rel_path = os.path.relpath(file_path, os.path.dirname(profile_dir))
                    zipf.write(file_path, rel_path)
        
        return send_file(
            temp_file.name,
            as_attachment=True,
            download_name=f'{profile_name}.zip',
            mimetype='application/zip'
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/profiles/import', methods=['POST'])
def import_profile():
    """Import profile from archive (zip or tar.gz)"""
    import zipfile
    import tarfile
    import tempfile
    
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    # Save uploaded file temporarily
    # We don't enforce extension check here to allow flexibility
    suffix = os.path.splitext(file.filename)[1]
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    file.save(temp_file.name)
    
    try:
        profile_name = None
        
        # Try opening as ZIP
        if zipfile.is_zipfile(temp_file.name):
            with zipfile.ZipFile(temp_file.name, 'r') as zipf:
                file_list = zipf.namelist()
                if not file_list:
                    raise Exception('Empty archive')
                
                # Get profile name
                first_item = file_list[0]
                if '/' in first_item:
                    profile_name = first_item.split('/')[0]
                else:
                    profile_name = os.path.splitext(file.filename)[0]
                
                profile_dir = docker_mgr.get_profile_dir(profile_name)
                if os.path.exists(profile_dir):
                    raise Exception(f'Profile {profile_name} already exists')
                
                zipf.extractall(path=CHROME_PROFILES_DIR)
                
        # Try opening as TAR (tar.gz, .tgz, etc)
        elif tarfile.is_tarfile(temp_file.name):
            with tarfile.open(temp_file.name, 'r:*') as tar:
                members = tar.getmembers()
                if not members:
                    raise Exception('Empty archive')
                
                # Get profile name
                profile_name = members[0].name.split('/')[0]
                profile_dir = docker_mgr.get_profile_dir(profile_name)
                
                if os.path.exists(profile_dir):
                    raise Exception(f'Profile {profile_name} already exists')
                
                tar.extractall(path=CHROME_PROFILES_DIR)
        else:
            raise Exception('Unsupported archive format. Please use .zip or .tar.gz')
            
        # Create desktop entry
        if profile_name:
            desktop_mgr.create_desktop_entry(profile_name)
        
        # Clean up temp file
        os.unlink(temp_file.name)
        
        return jsonify({
            'status': 'imported',
            'name': profile_name,
            'path': docker_mgr.get_profile_dir(profile_name)
        })
    except Exception as e:
        if os.path.exists(temp_file.name):
            os.unlink(temp_file.name)
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"🚀 Chrome Isolation Manager starting on http://{HOST}:{PORT}")
    print(f"📁 Profiles directory: {CHROME_PROFILES_DIR}")
    app.run(host=HOST, port=PORT, debug=DEBUG)
