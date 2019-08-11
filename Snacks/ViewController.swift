import CoreML
import Vision
import UIKit

class ViewController: UIViewController {
  
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var photoLibraryButton: UIButton!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!

  lazy var classificationReq:VNCoreMLRequest = {
    do
    {
      let healthy = HealthySnacks()
      let vnModel   = try VNCoreMLModel(for: healthy.model)
      let request = VNCoreMLRequest(model: vnModel, completionHandler: {
        [weak self] request, error in
        self?.processObservations(for: request, error: error )
      })

      request.imageCropAndScaleOption = .centerCrop

      return request
    }
    catch
    {
      fatalError("Failed to create VNCoreMLModel: \(error)")
    }
  }()


  func processObservations(for request:VNRequest, error:Error?) {

    DispatchQueue.main.async
    {
      if let results = request.results as? [ VNClassificationObservation ]
      {
        if results.isEmpty
        { self.resultsLabel.text = "Nothing found"
        }
        else if // less than 80% confident
        results[0].confidence < 0.8
        { self.resultsLabel.text = "Not sure"
        }
        else
        { self.resultsLabel.text = String(
            format: "%@ %.1f%%",
            results[0].identifier,
            results[0].confidence * 100 )
        }
      }
      else
      if let error = error
      { self.resultsLabel.text = "error: \(error.localizedDescription)"
      }
      else
      { self.resultsLabel.text = "???"
      }

      self.showResultsView()

    } // DispatchQueue.main.async

  }


  var firstTime = true

  override func viewDidLoad() {
    super.viewDidLoad()
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a photo"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Show the "choose or take a photo" hint when the app is opened.
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }
  
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }

  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }

  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()
  }

  func showResultsView(delay: TimeInterval = 0.1) {
    resultsConstraint.constant = 100
    view.layoutIfNeeded()

    UIView.animate(withDuration: 0.5,
                   delay: delay,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.6,
                   options: .beginFromCurrentState,
                   animations: {
      self.resultsView.alpha = 1
      self.resultsConstraint.constant = -10
      self.view.layoutIfNeeded()
    },
    completion: nil)
  }

  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }

  func classify(image: UIImage) {

    guard let ciimage = CIImage(image: image) else
    { print("Unable to create CIImage")
      return
    }

    let orientation = CGImagePropertyOrientation( image.imageOrientation )

    DispatchQueue.global(qos: .userInitiated ).async
    {
      let handler = VNImageRequestHandler(ciImage: ciimage, orientation: orientation)
      do
      {
        try handler.perform( [ self.classificationReq ] )
      }
      catch
      {
        print("Failed to perform classification: \(error)")
      }
    }

  }

} //ViewController

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

    picker.dismiss(animated: true)

	let image = info[.originalImage] as! UIImage
    imageView.image = image

    classify(image: image)
  }

}
