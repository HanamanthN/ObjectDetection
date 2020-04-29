import UIKit
import CoreML
import Vision
import ImageIO

class ImageClassificationViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var resultView: UIView!
    
    
    var objectConfidence: String = ""
    var rgbaArray = [CGFloat]()
    
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: Resnet50().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    func updateClassifications(for image: UIImage) {
        classificationLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    

    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                self.classificationLabel.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification -> String in
                    self.objectConfidence = classification.identifier
                   return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                }
                let colorOfObject = self.imageView.image?.areaAverage().cgColor
                
                self.rgbaArray = (colorOfObject?.components!)!
                
                debugPrint("EEE: array count \(self.rgbaArray)")
                
                self.red = self.rgbaArray[0]
                self.green = self.rgbaArray[1]
                self.blue = self.rgbaArray[2]
                self.alpha = self.rgbaArray[3]
                
                
                self.resultView.backgroundColor = UIColor(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
                
                self.classificationLabel.text = "Color: \(String(describing: colorOfObject?.components!))\n" + "Classification:\n" + descriptions.joined(separator: "\n")
                
                debugPrint("EEE: \(String(describing: colorOfObject))")
                debugPrint("EEE: \(String(describing: descriptions.first))")
                debugPrint("EEE: \(self.objectConfidence)")
//                debugPrint("EEE: \(String(describing: self.imageView.image?.areaAverage()))")
            }
        }
    }
    
    
    @IBAction func takePicture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        photoSourcePicker.addAction(UIAlertAction(title: "Take Photo", style: .default))
        self.presentPhotoPicker(sourceType: .camera)
//        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
//            self.presentPhotoPicker(sourceType: .camera)
//        }
        
        //photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(photoSourcePicker, animated: true)
    }
    
    func presentPhotoPicker(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
}

extension ImageClassificationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        picker.dismiss(animated: true)
        
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        updateClassifications(for: image)
    }
}

extension UIImage {
    func areaAverage() -> UIColor {
        var bitmap = [UInt8](repeating: 0, count: 4)

        if #available(iOS 9.0, *) {
            // Get average color.
            let context = CIContext()
            let inputImage: CIImage = ciImage ?? CoreImage.CIImage(cgImage: cgImage!)
            let extent = inputImage.extent
            let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
            let filter = CIFilter(name: "CIAreaAverage", withInputParameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent])!
            let outputImage = filter.outputImage!
            let outputExtent = outputImage.extent
            assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)

            // Render to bitmap.
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: kCIFormatRGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        } else {
            // Create 1x1 context that interpolates pixels when drawing to it.
            let context = CGContext(data: &bitmap, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let inputImage = cgImage ?? CIContext().createCGImage(ciImage!, from: ciImage!.extent)

            // Render to bitmap.
            context.draw(inputImage!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        // Compute result.
        let result = UIColor(red: CGFloat(bitmap[0])/255, green: CGFloat(bitmap[1])/255, blue: CGFloat(bitmap[2])/255, alpha: CGFloat(bitmap[3])/255)
        return result
    }
}

