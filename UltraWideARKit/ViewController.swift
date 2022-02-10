//
//  ViewController.swift
//  UltraWideARKit
//
//  SceneKit, UltraWide/Telephoto and some motion alts by Dan Monaghan on 2/11/22.

//  Original Code by Andrew Zheng - https://github.com/aheze/AlternativeARKit
//  Created by Zheng on 4/21/20.
//  Copyright © 2020 Zheng. All rights reserved.
//



import UIKit
import AVFoundation
import SceneKit
import GameController
import CoreMotion

class ViewController: UIViewController, SCNSceneRendererDelegate {

    @IBOutlet weak var cameraView: CameraView!

    let avSession = AVCaptureSession()
    let videoDataOutput = AVCaptureVideoDataOutput()

    var cameraDevice: AVCaptureDevice?
    var motionManager = CMMotionManager()
    var initialAttitude: CMAttitude?
    
    var motionX = Double(0) // Roll
    var motionY = Double(0) // Pitch
    var busyPerformingVisionRequest = false
    var aspectRatioWidthOverHeight: CGFloat = 0
    var deviceSize = CGSize()
    var cameraNode = SCNNode()
    var commonMaterial : SCNMaterial!
    
    lazy var sceneView: SCNView = {
        let sceneView = SCNView()
        sceneView.delegate = self
        return sceneView
    }()

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let currentAttitude = motionManager.deviceMotion?.attitude {
            initialAttitude = currentAttitude
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
           motionManager.startDeviceMotionUpdates()
           motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
           
           let interfaceOrientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation
           
           motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: OperationQueue.main, withHandler: { (motion: CMDeviceMotion?, err: Error?) in
               guard let m = motion else { return }

               self.sceneView.pointOfView!.orientation = m.gaze(atOrientation: interfaceOrientation!)
           })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        cameraNode.camera = SCNCamera()
        
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.camera!.motionBlurIntensity = 0
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        let floor = SCNNode(geometry: SCNBox(width: 30.1, height: 0.1, length: 30.2, chamferRadius: 0.0))
        floor.position = SCNVector3(x: 0, y: -2.3, z: 0)
        floor.geometry!.firstMaterial?.diffuse.contents = UIColor.systemPink
        floor.geometry?.firstMaterial?.transparency = 0.3
        floor.geometry?.firstMaterial?.isDoubleSided = true
//        scene.rootNode.addChildNode(floor)
        
        sceneView.scene = scene
        
//        sceneView.allowsCameraControl = true
        
        sceneView.showsStatistics = true
        
        sceneView.backgroundColor = UIColor.clear
        
        self.view.addSubview(sceneView)
        
        drawFloorGrid()
        
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        view.subviews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        sceneView.pointOfView?.camera?.focalLength = 9 // 9 seems ok, not perfect for UltraWide, telephoto is40
        cameraNode.geometry = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.0)
        cameraNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
 
        sceneView.isUserInteractionEnabled = true
//        sceneView.allowsCameraControl = true
        sceneView.delegate = self
        /// This is how often we will get device motion updates
        /// 0.03 is more than often enough and is about the rate that the video frame changes!
        motionManager.deviceMotionUpdateInterval = 0.03
        
        motionManager.startDeviceMotionUpdates(to: .main) {
            [weak self] (data, error) in
            guard let data = data, error == nil else {
                return
            }
            
            /// This function will be called every 0.03 seconds
//            self?.updateHighlightOrientations(attitude: data.attitude)
        }
        
        deviceSize = view.frame.size
        
//        blurView.layer.cornerRadius = 6
//        blurView.clipsToBounds = true
//        blurLabel.text = "Looking for this word: \"\(textToFind)\""
//
        /// Asks for permission to use the camera
        if isAuthorized() {
            configureCamera()
        }
        
    }
    
    func drawFloorGrid() {
        let geometry = SCNBox(width: 0.1 , height: 0.1,
                                       length: 0.1, chamferRadius: 0.1)
                geometry.firstMaterial?.diffuse.contents = UIColor.red
                geometry.firstMaterial?.specular.contents = UIColor.white
                geometry.firstMaterial?.emission.contents = UIColor.blue
                let boxnode = SCNNode(geometry: geometry)
                let offset: Int = 16

                for xIndex:Int in 0...64 {
                    for zIndex:Int in 0...64 {
                        let boxCopy = boxnode.copy() as! SCNNode
                        boxCopy.position.x = Float(xIndex - offset)
                        boxCopy.position.z = Float(zIndex - offset)
                        boxCopy.position.y = -2.3
                        sceneView.scene!.rootNode.addChildNode(boxCopy)
                    }
                }
    }
}



extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    // MARK: Camera Delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        connection.videoPreviewLayer?.frame = self.view.bounds
        

        if busyPerformingVisionRequest == false {
//            findUsingVision(in: pixelBuffer)
        }
    }
}


extension CMDeviceMotion {
    
    func gaze(atOrientation orientation: UIInterfaceOrientation) -> SCNVector4 {
        
        let attitude = self.attitude.quaternion
        let aq = GLKQuaternionMake(Float(attitude.x), Float(attitude.y), Float(attitude.z), Float(attitude.w))
        
        let final: SCNVector4
        
        switch orientation {
            
        case .landscapeRight:
            
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float.pi / 2, 0, 1, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            final = SCNVector4(x: -q.y, y: q.x, z: q.z, w: q.w)
            
        case .landscapeLeft:
            
            let cq = GLKQuaternionMakeWithAngleAndAxis(-Float.pi / 2, 0, 1, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            final = SCNVector4(x: q.y, y: -q.x, z: q.z, w: q.w)
            
        case .portraitUpsideDown:
            
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float.pi / 2, 1, 0, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            final = SCNVector4(x: -q.x, y: -q.y, z: q.z, w: q.w)
            
        case .unknown:
            
            fallthrough
            
        case .portrait:
            
            fallthrough
            
        @unknown default:
            
            let cq = GLKQuaternionMakeWithAngleAndAxis(-Float.pi / 2, 1, 0, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            final = SCNVector4(x: q.x, y: q.y, z: q.z, w: q.w)
        }
        
        return final
    }
}
