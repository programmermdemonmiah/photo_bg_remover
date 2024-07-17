from flask import Flask, request, send_file
from flask_cors import CORS
from rembg import remove
from PIL import Image
import io

app = Flask(__name__)
CORS(app)


# # Background removal function
# def remove_background(image_bytes):
#     try:
#         processed_bytes = rembg.remove(image_bytes)
#         return processed_bytes 
#     except Exception as e:
#         print(f'Error removing background: {e}')
#         raise


@app.route('/remove_background', methods=['POST'])
def remove_background():
    if 'file' not in request.files:
        app.logger.error("No image uploaded")
        return 'No file uploaded', 400
    
    file = request.files['file']
    
    if file.filename == '':
        app.logger.error("No selected file")
        return 'No selected file', 400
    
    if file:
        input_image = Image.open(file.stream)
        
        app.logger.info("Removing background")
        output = remove(input_image)
        
        app.logger.info("Background removed successfully")
        
        img_byte_arr = io.BytesIO()
        output.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        app.logger.info("Sending processed image back")
        return send_file(img_byte_arr, mimetype='image/png', as_attachment=True, download_name='removed_background.png')

if __name__ == '__main__':
    app.run(port='5000',debug=True)