import SceneKit
import UIKit

// MARK: - SceneKit Extensions

extension SCNVector3 {
    func dot(_ v: SCNVector3) -> Float { 
        return x * v.x + y * v.y + z * v.z 
    }
    
    func cross(_ v: SCNVector3) -> SCNVector3 {
        SCNVector3(y*v.z - z*v.y, z*v.x - x*v.z, x*v.y - y*v.x)
    }
    
    func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    func normalized() -> SCNVector3 {
        let len = length()
        if len == 0 {
            return SCNVector3(0, 0, 0)
        }
        return SCNVector3(x / len, y / len, z / len)
    }
}

// MARK: - UIView Extensions for finding subviews
extension UIView {
    func findSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }
        
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        
        return nil
    }
}

// MARK: - Shared Scene Building Functions

struct SceneKitUtils {
    static func createCylinderBetween(
        _ start: SCNVector3, 
        _ end: SCNVector3, 
        radius: CGFloat, 
        color: UIColor,
        segments: Int = 16
    ) -> SCNNode {
        let vector = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let length = CGFloat(sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z))
        
        let cylinder = SCNCylinder(radius: radius, height: length)
        cylinder.radialSegmentCount = segments
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 16.0
        material.lightingModel = .physicallyBased
        cylinder.materials = [material]
        
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((start.x + end.x)/2, (start.y + end.y)/2, (start.z + end.z)/2)
        
        // Orientation
        let up = SCNVector3(0, 1, 0)
        let direction = SCNVector3(
            Float(vector.x)/Float(length), 
            Float(vector.y)/Float(length), 
            Float(vector.z)/Float(length)
        )
        let axis = up.cross(direction)
        let angle = acos(CGFloat(up.dot(direction)))
        node.rotation = SCNVector4(axis.x, axis.y, axis.z, Float(angle))
        
        return node
    }
    
    static func frameScene(_ scene: SCNScene, distance: Float = 2.0) {
        let (minVec, maxVec) = scene.rootNode.boundingBox
        let size = SCNVector3(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        let center = SCNVector3((minVec.x + maxVec.x)/2, (minVec.y + maxVec.y)/2, (minVec.z + maxVec.z)/2)
        
        let camera = SCNCamera()
        camera.zFar = 10000
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        let maxDim = max(size.x, max(size.y, size.z))
        let cameraDistance = CGFloat(maxDim) * CGFloat(distance)
        cameraNode.position = SCNVector3(center.x, center.y, center.z + Float(cameraDistance))
        cameraNode.look(at: center)
        scene.rootNode.addChildNode(cameraNode)
    }
    
    static func createEnhancedMaterial(color: UIColor, style: MaterialStyle = .standard) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.lightingModel = .physicallyBased
        
        switch style {
        case .standard:
            material.shininess = 32.0
            material.metalness.contents = 0.1
            material.roughness.contents = 0.3
        case .glossy:
            material.shininess = 64.0
            material.metalness.contents = 0.2
            material.roughness.contents = 0.1
        case .matte:
            material.shininess = 16.0
            material.metalness.contents = 0.05
            material.roughness.contents = 0.5
        }
        
        return material
    }
    
    static func moveCamera(sceneView: SCNView, to position: SCNVector3, duration: TimeInterval = 1.0) {
        guard let camera = sceneView.pointOfView else { return }
        
        // 목표 위치와 현재 카메라 위치 사이의 거리 계산
        let currentPosition = camera.position
        let distance = sqrt(
            pow(position.x - currentPosition.x, 2) +
            pow(position.y - currentPosition.y, 2) +
            pow(position.z - currentPosition.z, 2)
        )
        
        // 거리에 따라 카메라 줌 조정
        let idealDistance = Float(min(max(distance * 2.0, 5.0), 30.0))
        
        // 카메라가 보는 방향으로 이동할 위치 계산
        let cameraDirection = SCNVector3(0, 0, idealDistance)
        let rotatedDirection = camera.convertPosition(cameraDirection, to: nil)
        let targetCameraPosition = SCNVector3(
            position.x + rotatedDirection.x,
            position.y + rotatedDirection.y,
            position.z + rotatedDirection.z
        )
        
        // 애니메이션 생성
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 카메라가 위치를 바라보도록 설정
        camera.look(at: position)
        
        // 카메라 위치 이동
        camera.position = targetCameraPosition
        
        SCNTransaction.commit()
    }
}

enum MaterialStyle {
    case standard
    case glossy
    case matte
}
