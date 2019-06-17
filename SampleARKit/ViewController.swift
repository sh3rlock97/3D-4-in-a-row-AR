//
//  ViewController.swift
//  SampleARKit
//
//  Created by Marino Schmid on 28.10.18.
//  Copyright © 2018 Marino Schmid. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity



class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    

    @IBOutlet weak var sessionInfoLabel: UILabel!
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
        
    }
    
    var mapProvider: MCPeerID?
    
    /// - Tag: ReceiveData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                // Run the session with the received world map.
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
                mapProvider = peer
            }
            else
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                    // Add anchor to the session, ARSCNView delegate adds visible content.
                    sceneView.session.add(anchor: anchor)
                }
            else
                    if let node = try NSKeyedUnarchiver.unarchivedObject(ofClass: gameNode.self, from: data) {
                        // Add anchor to the session, ARSCNView delegate adds visible content.
                        scene = SCNScene()
                        scene.rootNode.addChildNode(node)
                        print("received nodes?")
                    }
                else {
                    print("unknown data recieved from \(peer)")
            }
        } catch {
            print("can't decode data recieved from \(peer)")
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking(nil)
    }
    
    @IBAction func resetTracking(_ sender: UIButton?) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    // MARK: - AR session management
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        sessionInfoLabel.text = message
      //  sessionInfoView.isHidden = message.isEmpty
    }
    
    
    
    
    @IBOutlet var sceneView: ARSCNView!
    var scene : SCNScene = SCNScene()
    let node = gameNode();
    
    var set  = false
    var multipeerSession: MultipeerSession!

    

    @IBAction func hit(_ sender: UITapGestureRecognizer) {
        
        // check what nodes are tapped
        var p = sender.location(in: sceneView)
        
        if(!set) {
            
            let result = sceneView.hitTest(p, types: .existingPlaneUsingExtent)
            if(result.count > 0) {
                // Create a new scene
                scene = SCNScene()
                node.setup()
                scene.rootNode.addChildNode(node)
                node.scale.x *= 0.004
                node.scale.z *= 0.004
                node.scale.y *= 0.004
                // Set the scene to the view
                sceneView.scene = scene
                let position = SCNVector3(
                    result[0].worldTransform.columns.3.x,
                    result[0].worldTransform.columns.3.y,
                    result[0].worldTransform.columns.3.z
                )
                node.position = position
                set = true
                
                let alertController = UIAlertController(title: "Gut!", message: "", preferredStyle: .alert)
                //We add buttons to the alert controller by creating UIAlertActions:
                let actionOk = UIAlertAction(title: "OK",
                                             style: .default,
                                             handler: nil) //You can use a block here to handle a press on this button
                
                alertController.addAction(actionOk)
                self.present(alertController, animated: true, completion: nil)
            } else {
                let alertController = UIAlertController(title: "Schlecht!", message: "Keine Fläche gefunden, erneut versuchen.", preferredStyle: .alert)
                //We add buttons to the alert controller by creating UIAlertActions:
                let actionOk = UIAlertAction(title: "OK",
                                             style: .default,
                                             handler: nil) //You can use a block here to handle a press on this button
                
                alertController.addAction(actionOk)
                self.present(alertController, animated: true, completion: nil)
            }
            
            shareSession(UIButton())
            
        }
        
        var hitResults = sceneView.hitTest(p, options: nil)
        if hitResults.count > 0
        {
            
            var hitnode = (hitResults.first)!.node
            var normal = (hitResults.first)!.localNormal
            print("\nName of node hit is \(hitnode.name)")
            print(normal)
            if round(normal.z) == -1 {
                print("TOP?")
                node.add(hitnode)
            }
            
            //var indexvalue = hitResults.first?.faceIndex
            //print(indexvalue)
        }
        
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    

    @IBAction func reload(_ sender: Any) {
        self.present(self, animated: false, completion: nil)
        
//        scene = SCNScene()
//        node.setup()
//        scene.rootNode.addChildNode(node)
//        node.scale.x *= 0.01
//        node.scale.z *= 0.01
//        node.scale.y *= 0.01
//        // Set the scene to the view
//        sceneView.scene = scene
    }
    
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        // Here `anchor` is an ARPlaneAnchor
        addPlane(for: node, at: anchor)
    }
    
    func addPlane(for node: SCNNode, at anchor: ARPlaneAnchor) {
        // Create a new node
        let planeNode = SCNNode()
        
        let w = CGFloat(anchor.extent.x)
        let h : CGFloat = 0.01
        let l = CGFloat(anchor.extent.z)
        
        // Box Geometry with a minimum height
        let geometry   = SCNBox(width: w, height: h, length: l, chamferRadius: 0.0)
        
        // Translucent white plane
        geometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
        
        // Set Position
        // Use the `center` property to find the bounds of the anchor to place the node
        planeNode.position = SCNVector3(
            anchor.center.x,
            anchor.center.y,
            anchor.center.z
        )
        
        // Keep a reference to plane you're adding, so you can update it later
        planes[anchor] = planeNode
        
        // Add PlaneNode to your node
        node.addChildNode(planeNode)
    }
    
    var planes = [ARPlaneAnchor: SCNNode]()
    
    func updatePlane(for anchor: ARPlaneAnchor) {
        
        // Pull the plane that needs to get updated
        let plane = self.planes[anchor]
        
        // Update its geometry
        if let geometry = plane?.geometry as? SCNBox {
            geometry.width  = CGFloat(anchor.extent.x)
            geometry.length = CGFloat(anchor.extent.y)
            geometry.height = 0.01
        }
        
        // Update its position
        plane?.position = SCNVector3(
            anchor.center.x,
            anchor.center.y,
            anchor.center.z
        )
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Verify the updated anchor is an ARPlaneAnchor
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        
        //  Update the plane
        updatePlane(for: anchor)
    }
}








class gameNode : SCNNode {
    var player = true
    var grid : [SCNNode] = []
    var cameraNode = SCNCamera()
    var rotated : Float = 0;
    var startx : Float = 0.0;
    var starty : Float = 0.0;
    var startz : Float = 0.0;

    var fields : [[[Int]]] = []
    func setup() {
        for z in 0..<4 {
            fields.append([])
            for y in 0..<4 {
                fields[z].append([])
                for _ in 0..<4 {
                    fields[z][y].append(-1)
                }
            }
        }
        print(fields)
        for i in 0..<16 {
            let x : Float = Float(i%4)-1.5
            let y : Float = Float(i/4)-1.5
            let box = SCNBox(width: 9.5, height: 9.5, length: 9.5, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 0.9)
            let boxnode = SCNNode(geometry: box)
            startx = boxnode.position.x;
            starty = boxnode.position.y;
            startz = boxnode.position.z;
            boxnode.position = SCNVector3(boxnode.position.x+10*x, boxnode.position.y+10*y, boxnode.position.z)
            self.addChildNode(boxnode)
            grid.append(boxnode)
            boxnode.name = "\(i%4) \(i/4) -1";
        }
        self.eulerAngles = SCNVector3(Double.pi/2, 0, 0)
        rotated = 0;
        
        
        rot()
    }
    
    @objc func rot() {
        //        let pos = SCNVector3(self.position.x,self.position.y,self.position.z)
        //        for node in grid {
        //            node.rotate(by: SCNQuaternion(0,0.02,0,1), aroundTarget: pos)
        //        }
        //        self.eulerAngles.y += 0.02
        //        if(self.eulerAngles.y.truncatingRemainder(dividingBy: Float.pi*2) < Float.pi) {
        //            self.eulerAngles.x -= 0.005
        //        } else {
        //            self.eulerAngles.x += 0.005
        //        }
        
        //        if(self.eulerAngles.y.truncatingRemainder(dividingBy: Float.pi*2) > Float.pi/2 && self.eulerAngles.y.truncatingRemainder(dividingBy: Float.pi*2) < Float.pi/2*3) {
        //            self.eulerAngles.z -= 0.005
        //
        //        } else {
        //            self.eulerAngles.z += 0.005
        //
        //        }
        
        // self.rotate(by: SCNQuaternion(x: 0, y: 0.1, z: 0, w: 1), aroundTarget: SCNVector3(self.eulerAngles.x,self.eulerAngles.y,self.eulerAngles.z))
        
        
        
        //let timer = Timer.scheduledTimer(timeInterval: TimeInterval(0.03),
        //target: self, selector: #selector(gameNode.rot), userInfo: nil, repeats: false)
    }
    
    func rota(_ by : CGFloat) {
        let orientation = self.orientation
        var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
        
        // Rotate around Z axis
        rotated += Float(by)
        let multiplier = GLKQuaternionMakeWithAngleAndAxis(Float(by), 0, 0, 1)
        glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)
        
        self.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
    }
    func rotb(_ by : CGFloat) {
        self.rotate(by: SCNQuaternion(by, 0, 0, 1), aroundTarget: self.position)
    }
    
    func testWin(_ p: Int, _ x: Int, _ y: Int, _ z: Int, _ mx : Int,_ my : Int,_ mz : Int, _ c : Bool) -> Bool {
        var sum = 0;
        var left = true
        var right = true
        
        for i in [0,1,-1,2,-2,3,-3] {
            
            print("????: \(x+i*mx) \(y+i*my) \(z+i*mz) \(p) ")
            
            if i>0 && !right {
                continue
            }
            if i<0 && !left {
                continue
            }
            
            if !(fields.count > x+i*mx && x+i*mx >= 0 && fields[x+i*mx].count > y+i*my && y+i*my >= 0 && fields[x+i*mx][y+i*my].count > z+i*mz && z+i*mz >= 0) {
                continue;
            }
            print(fields[x+i*mx][y+i*my][z+i*mz])
            if(fields[x+i*mx][y+i*my][z+i*mz] == p) {
                print("????AA: \(x+i*mx) \(y+i*my) \(z+i*mz)")
                if(c) {
                    print("Cieg: \(x+i*mx) \(y+i*my) \(z+i*mz)")
                    
                    let heightNewNode : Float = 8;
                    let box = SCNBox(width: CGFloat(heightNewNode)-1, height: CGFloat(heightNewNode)-1, length: CGFloat(heightNewNode)-1, chamferRadius: 0)
                    box.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
                    let boxnode = SCNNode(geometry: box)

                    let xx : Float = Float((x+i*mx)*10)-15;
                    let yy : Float = Float(y+i*my)-1.5
                    let zz : Float = Float(z+i*mz)
                    boxnode.position = SCNVector3(xx+startx, (yy)*10+starty, (startz)-7*(zz+1)-3)
                    self.addChildNode(boxnode)
                }
                sum += 1
                if(sum == 4) {
                    print("Sieg: \(x+i*mx) \(y+i*my) \(z+i*mz)")
                    if(!c) {
                        _ = testWin(p, x, y, z, mx, my, mz, true)
                    }
                    return true
                }
            } else {
                if(i>0) {
                    right = false;
                } else{
                    left = false
                }
            }
        }
        print("FALSE!")
        return false
    }
    var stopped = false;
    func add(_ hitnode : SCNNode) {
        if(stopped) {return;}
        print(hitnode.name)
        var xyz = (hitnode.name)!.split(separator: " ")
        print(xyz)
        var x = Int(xyz[0])!
        var y = Int(xyz[1])!
        var z = Int(xyz[2])!+1
        if(z <= 3 && fields[x][y][z] == -1) {
            fields[x][y][z] = player ? 1 : 0
        } else {
            return;
        }
        
        // diagonal win
        print("START \(x) \(y) \(z)")
        if(
            testWin(player ? 1 : 0, x, y, z, 1, 1, 1,false)
                || testWin(player ? 1 : 0, x, y, z, 1, 1, -1,false)
                || testWin(player ? 1 : 0, x, y, z, 1, 1, 0,false)
                || testWin(player ? 1 : 0, x, y, z, -1, 1, 1,false)
                || testWin(player ? 1 : 0, x, y, z, -1, 1, -1,false)
                || testWin(player ? 1 : 0, x, y, z, -1, 1, 0,false)
                || testWin(player ? 1 : 0, x, y, z, 1, 0, 0,false)
                || testWin(player ? 1 : 0, x, y, z, 1, 0, 1,false)
                || testWin(player ? 1 : 0, x, y, z, 0, 1, 1,false)
                || testWin(player ? 1 : 0, x, y, z, 1, 0, -1,false)
                || testWin(player ? 1 : 0, x, y, z, 0, 1, -1,false)
                || testWin(player ? 1 : 0, x, y, z, 0, 1, 0,false)
                || testWin(player ? 1 : 0, x, y, z, 0, 0, 1,false)
            ) {
            print("Sieg")
            stopped = true
        }
         
        

        
        let heightNewNode : Float = 7;
        let box = SCNBox(width: CGFloat(heightNewNode)-1, height: CGFloat(heightNewNode)-1, length: CGFloat(heightNewNode)-1, chamferRadius: 1)
        //let box = SCNSphere(radius: 3)
        if(player) {
            box.firstMaterial?.diffuse.contents = UIColor.red
        } else {
            box.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 0.9)
        }
        let boxnode = SCNNode(geometry: box)
        boxnode.name = "\(x) \(y) \(z)"
        let heightHitnode = (hitnode.geometry?.boundingBox.max.z ?? 0)-(hitnode.geometry?.boundingBox.min.z ?? 0)
        let height = (heightNewNode + heightHitnode)/2
        boxnode.position = SCNVector3(hitnode.position.x, hitnode.position.y, hitnode.position.z-height)
        self.addChildNode(boxnode)
        player = !player
    }
    
}










import MultipeerConnectivity

/// - Tag: MultipeerSession
class MultipeerSession: NSObject {
    static let serviceType = "ar-multi-sample"
    
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    
    private let receivedDataHandler: (Data, MCPeerID) -> Void
    
    /// - Tag: MultipeerSetup
    init(receivedDataHandler: @escaping (Data, MCPeerID) -> Void ) {
        self.receivedDataHandler = receivedDataHandler
        
        super.init()
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: MultipeerSession.serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: MultipeerSession.serviceType)
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }
    
    func sendToAllPeers(_ data: Data) {
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("error sending data to peers: \(error.localizedDescription)")
        }
    }
    
    var connectedPeers: [MCPeerID] {
        return session.connectedPeers
    }
}

extension MultipeerSession: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // not used
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receivedDataHandler(data, peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        fatalError("This service does not send/receive streams.")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        fatalError("This service does not send/receive resources.")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        fatalError("This service does not send/receive resources.")
    }
    
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    
    /// - Tag: FoundPeer
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Invite the new peer to the session.
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // This app doesn't do anything with non-invited peers, so there's nothing to do here.
    }
    
}

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    
    /// - Tag: AcceptInvite
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Call handler to accept invitation and join the session.
        invitationHandler(true, self.session)
    }
    
}
