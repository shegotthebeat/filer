from flask import Flask, request, send_file, render_template_string, jsonify
import os
import requests
from werkzeug.utils import secure_filename
import uuid
from datetime import datetime

app = Flask(__name__)
STORAGE_PATH = "/mnt/storage/uploads"
os.makedirs(STORAGE_PATH, exist_ok=True)

# [MINIMALIST HTML TEMPLATE - Same as your current design]
UPLOAD_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Hub</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            font-size: 12px; line-height: 1.4; color: #000; background: #fff;
            height: 100vh; overflow: hidden;
        }
        .container { display: flex; height: 100vh; }
        .sidebar {
            width: 200px; background: #000; color: #fff; padding: 20px;
            position: fixed; height: 100vh; overflow: hidden;
        }
        .sidebar h1 {
            font-size: 14px; font-weight: normal; margin-bottom: 30px;
            text-transform: uppercase; letter-spacing: 1px;
        }
        .nav-item { margin-bottom: 15px; font-size: 11px; }
        .nav-item a { color: #fff; text-decoration: none; }
        .nav-item a:hover { text-decoration: underline; }
        .storage-info { margin-top: 40px; font-size: 11px; color: #ccc; }
        .content {
            margin-left: 200px; padding: 20px; height: 100vh;
            overflow-y: auto; flex: 1;
        }
        .upload-form { border: 1px solid #000; padding: 20px; margin-bottom: 20px; max-width: 400px; }
        .form-title {
            font-size: 12px; font-weight: normal; margin-bottom: 15px;
            text-transform: uppercase; letter-spacing: 1px;
        }
        .form-group { margin-bottom: 15px; }
        .form-control {
            width: 100%; padding: 8px; border: 1px solid #000; background: #fff;
            font-size: 11px; font-family: inherit;
        }
        .form-control:focus { outline: none; background: #f9f9f9; }
        .btn {
            background: #000; color: #fff; border: none; padding: 8px 16px;
            font-size: 11px; cursor: pointer; text-transform: uppercase; letter-spacing: 1px;
        }
        .btn:hover { background: #333; }
        .upload-status { margin-top: 15px; font-size: 11px; padding: 8px; display: none; }
        .upload-status.success { background: #f0f0f0; border: 1px solid #000; }
        .upload-status.error { background: #000; color: #fff; border: 1px solid #000; }
        .file-entry { padding: 10px 0; border-bottom: 1px solid #eee; font-size: 11px; }
        .file-entry:last-child { border-bottom: none; }
        .file-name { color: #000; text-decoration: none; font-weight: normal; }
        .file-name:hover { text-decoration: underline; }
        .file-meta { color: #666; margin-top: 2px; }
        @media (max-width: 768px) {
            .sidebar { width: 100%; height: auto; position: relative; padding: 15px; }
            .content { margin-left: 0; padding: 15px; }
            .container { flex-direction: column; height: auto; }
            body { overflow: auto; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="sidebar">
            <h1>File Hub</h1>
            <div class="nav-item"><a href="/files">View Files</a></div>
            <div class="nav-item"><a href="/">Upload</a></div>
            <div class="storage-info">
                Storage<br>{{ storage_info.free_gb }}GB free<br>{{ storage_info.total_gb }}GB total
            </div>
        </div>
        <div class="content">
            <!-- Mobile form -->
            <form id="mobileForm" method="post" action="/upload" enctype="multipart/form-data" style="display: none;">
                <div class="upload-form">
                    <div class="form-title">Upload Files</div>
                    <div class="form-group">
                        <input type="file" name="file" class="form-control" multiple>
                    </div>
                    <button type="submit" class="btn">Upload</button>
                    <div class="upload-status" id="mobileStatus"></div>
                </div>
            </form>
            <!-- Desktop upload -->
            <div id="desktopUpload">
                <div class="upload-form">
                    <div class="form-title">Upload Files</div>
                    <input type="file" id="fileInput" multiple style="width: 100%; padding: 8px; border: 1px solid #000; background: #fff; font-size: 11px;">
                    <div class="upload-status" id="uploadStatus"></div>
                </div>
                <div class="upload-form">
                    <div class="form-title">Download from URL</div>
                    <div class="form-group">
                        <input type="url" id="urlInput" class="form-control" placeholder="https://example.com/file.pdf">
                    </div>
                    <button class="btn" onclick="downloadFromUrl()">Download</button>
                    <div class="upload-status" id="urlStatus"></div>
                </div>
            </div>
            <div style="margin-top: 30px;">
                <div class="form-title">Recent Files ({{ file_count }})</div>
                <div id="recentFiles">Loading...</div>
            </div>
        </div>
    </div>
    <script>
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth <= 768;
        
        if (isMobile) {
            document.getElementById('mobileForm').style.display = 'block';
            document.getElementById('desktopUpload').style.display = 'none';
        } else {
            document.getElementById('fileInput').addEventListener('change', (e) => {
                const files = e.target.files;
                if (files.length > 0) uploadFiles(files);
            });
        }

        function uploadFiles(files) {
            const formData = new FormData();
            for (let i = 0; i < files.length; i++) {
                formData.append('files', files[i]);
            }
            showStatus('uploadStatus', 'Uploading...', 'success');
            fetch('/upload-multiple', { method: 'POST', body: formData })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showStatus('uploadStatus', `Uploaded ${data.count} file(s)`, 'success');
                    loadRecentFiles();
                } else {
                    showStatus('uploadStatus', data.message, 'error');
                }
            })
            .catch(error => showStatus('uploadStatus', 'Upload failed', 'error'));
        }

        function downloadFromUrl() {
            const url = document.getElementById('urlInput').value;
            if (!url) { showStatus('urlStatus', 'Enter URL', 'error'); return; }
            showStatus('urlStatus', 'Downloading...', 'success');
            fetch('/download-url', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({url: url})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showStatus('urlStatus', 'Downloaded', 'success');
                    document.getElementById('urlInput').value = '';
                    loadRecentFiles();
                } else {
                    showStatus('urlStatus', data.message, 'error');
                }
            })
            .catch(error => showStatus('urlStatus', 'Download failed', 'error'));
        }

        function showStatus(elementId, message, type) {
            const element = document.getElementById(elementId);
            element.textContent = message;
            element.className = `upload-status ${type}`;
            element.style.display = 'block';
            setTimeout(() => element.style.display = 'none', 3000);
        }

        function loadRecentFiles() {
            fetch('/api/files')
            .then(response => response.json())
            .then(data => {
                const container = document.getElementById('recentFiles');
                if (data.files.length === 0) {
                    container.innerHTML = 'No files uploaded yet';
                    return;
                }
                container.innerHTML = data.files.slice(0, 10).map(file => {
                    const displayName = file.filename.includes('_') ? file.filename.split('_').slice(1).join('_') : file.filename;
                    const date = new Date(file.created).toLocaleDateString();
                    return `<div class="file-entry">
                        <a href="/download/${file.filename}" class="file-name">${displayName}</a>
                        <div class="file-meta">${file.size_mb}MB • ${date}</div>
                    </div>`;
                }).join('');
            })
            .catch(() => {
                document.getElementById('recentFiles').innerHTML = 'Error loading files';
            });
        }
        loadRecentFiles();
    </script>
</body>
</html>
'''

# [ALL YOUR FLASK ROUTES - Same as current implementation]
@app.route('/')
def index():
    import shutil
    total, used, free = shutil.disk_usage('/mnt/storage')
    storage_info = {
        'total_gb': total // (1024**3),
        'free_gb': free // (1024**3)
    }
    file_count = len(os.listdir(STORAGE_PATH))
    return render_template_string(UPLOAD_TEMPLATE, storage_info=storage_info, file_count=file_count)

@app.route('/upload', methods=['POST'])
def upload_file():
    try:
        files = request.files.getlist('file')
        if not files or not files[0].filename:
            return 'No files selected<br><a href="/">Back</a>'
        
        uploaded_count = 0
        uploaded_names = []
        
        for file in files:
            if file and file.filename:
                filename = secure_filename(file.filename)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                unique_filename = f"{timestamp}_{filename}"
                filepath = os.path.join(STORAGE_PATH, unique_filename)
                file.save(filepath)
                uploaded_count += 1
                uploaded_names.append(filename)
        
        return f'''
        <!DOCTYPE html>
        <html><head><title>Upload Complete</title>
        <style>
        body {{font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 12px; color: #000; background: #fff; margin: 0; padding: 20px;}}
        .container {{max-width: 400px; margin: 50px auto; padding: 20px; border: 1px solid #000;}}
        .title {{font-size: 12px; font-weight: normal; margin-bottom: 20px; text-transform: uppercase; letter-spacing: 1px;}}
        .file-list ul {{list-style: none; padding: 0;}}
        .file-list li {{padding: 4px 0; font-size: 11px; border-bottom: 1px solid #eee;}}
        .btn {{background: #000; color: #fff; border: none; padding: 8px 16px; font-size: 11px; text-decoration: none; text-transform: uppercase; letter-spacing: 1px; margin-right: 10px; display: inline-block; margin-bottom: 10px;}}
        </style></head><body>
        <div class="container">
            <div class="title">Upload Complete</div>
            <p>Successfully uploaded {uploaded_count} file(s):</p>
            <div class="file-list"><ul>{"".join(f"<li>{name}</li>" for name in uploaded_names)}</ul></div>
            <div><a href="/files" class="btn">View Files</a><a href="/" class="btn">Upload More</a></div>
        </div></body></html>
        '''
    except Exception as e:
        return f'Upload failed: {str(e)}<br><a href="/">Back</a>'

@app.route('/upload-multiple', methods=['POST'])
def upload_multiple_files():
    try:
        files = request.files.getlist('files')
        uploaded_count = 0
        
        for file in files:
            if file and file.filename:
                filename = secure_filename(file.filename)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                unique_filename = f"{timestamp}_{filename}"
                filepath = os.path.join(STORAGE_PATH, unique_filename)
                file.save(filepath)
                uploaded_count += 1
        
        return jsonify({
            'success': True,
            'count': uploaded_count,
            'message': f'Successfully uploaded {uploaded_count} file(s)'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/download-url', methods=['POST'])
def download_from_url():
    try:
        data = request.get_json()
        url = data.get('url')
        
        if not url:
            return jsonify({'success': False, 'message': 'No URL provided'})
        
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        filename = os.path.basename(url.split('?')[0]) or "downloaded_file"
        filename = secure_filename(filename)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_filename = f"{timestamp}_{filename}"
        filepath = os.path.join(STORAGE_PATH, unique_filename)
        
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        return jsonify({
            'success': True,
            'message': f'Downloaded: {filename}',
            'filename': unique_filename
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/files')
def list_files():
    files = os.listdir(STORAGE_PATH)
    files.sort(reverse=True)
    
    # [MINIMALIST FILE LIST HTML - Same as your current design]
    file_list = '''<!DOCTYPE html><html><head><title>File Library</title>
    <style>
    * {margin: 0; padding: 0; box-sizing: border-box;}
    body {font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 12px; color: #000; background: #fff; height: 100vh; overflow: hidden;}
    .container {display: flex; height: 100vh;}
    .sidebar {width: 200px; background: #000; color: #fff; padding: 20px; position: fixed; height: 100vh;}
    .sidebar h1 {font-size: 14px; font-weight: normal; margin-bottom: 30px; text-transform: uppercase; letter-spacing: 1px;}
    .nav-item {margin-bottom: 15px; font-size: 11px;}
    .nav-item a {color: #fff; text-decoration: none;}
    .nav-item a:hover {text-decoration: underline;}
    .storage-info {margin-top: 40px; font-size: 11px; color: #ccc;}
    .content {margin-left: 200px; padding: 20px; height: 100vh; overflow-y: auto;}
    .file-entry {padding: 8px 0; border-bottom: 1px solid #eee; font-size: 11px;}
    .file-name {color: #000; text-decoration: none; display: block;}
    .file-name:hover {text-decoration: underline;}
    .file-meta {color: #666; margin-top: 2px;}
    .page-title {font-size: 12px; font-weight: normal; margin-bottom: 20px; text-transform: uppercase; letter-spacing: 1px;}
    </style></head><body>
    <div class="container">
        <div class="sidebar">
            <h1>File Hub</h1>
            <div class="nav-item"><a href="/files">View Files</a></div>
            <div class="nav-item"><a href="/">Upload</a></div>
            <div class="storage-info">Storage<br>Loading...</div>
        </div>
        <div class="content">
            <div class="page-title">All Files</div>'''
    
    for file in files:
        filepath = os.path.join(STORAGE_PATH, file)
        size = os.path.getsize(filepath) / (1024*1024)
        date = datetime.fromtimestamp(os.path.getctime(filepath)).strftime('%Y-%m-%d')
        display_name = file.split('_', 1)[1] if '_' in file else file
        file_list += f'<div class="file-entry"><a href="/download/{file}" class="file-name">{display_name}</a><div class="file-meta">{size:.1f}MB • {date}</div></div>'
    
    if not files:
        file_list += '<div class="file-entry">No files uploaded yet</div>'
    
    file_list += '''</div></div>
    <script>
    fetch('/storage-info').then(r=>r.json()).then(d=>{
        document.querySelector('.storage-info').innerHTML=`Storage<br>${d.free_gb}GB free<br>${d.total_gb}GB total`;
    }).catch(()=>{document.querySelector('.storage-info').innerHTML='Storage<br>Info unavailable';});
    </script></body></html>'''
    
    return file_list

@app.route('/download/<filename>')
def download_file(filename):
    filepath = os.path.join(STORAGE_PATH, secure_filename(filename))
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return 'File not found', 404

@app.route('/storage-info')
def storage_info():
    import shutil
    total, used, free = shutil.disk_usage('/mnt/storage')
    return jsonify({
        'total_bytes': total, 'used_bytes': used, 'free_bytes': free,
        'total_gb': total // (1024**3), 'used_gb': used // (1024**3), 
        'free_gb': free // (1024**3), 'usage_percent': round((used/total)*100, 1)
    })

@app.route('/api/files')
def api_files():
    files = []
    for file in os.listdir(STORAGE_PATH):
        filepath = os.path.join(STORAGE_PATH, file)
        files.append({
            'filename': file,
            'size_bytes': os.path.getsize(filepath),
            'size_mb': round(os.path.getsize(filepath) / (1024*1024), 2),
            'created': datetime.fromtimestamp(os.path.getctime(filepath)).isoformat(),
            'download_url': f'/download/{file}'
        })
    return jsonify({'files': files, 'count': len(files)})

if __name__ == '__main__':
    print(f"File service starting on port 5001...")
    print(f"Storage: {STORAGE_PATH}")
    app.run(host='0.0.0.0', port=5001, debug=False)
