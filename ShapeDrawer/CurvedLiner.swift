//
//  CurvedLiner.swift
//  ShapeDrawer
//
//  Created by Tai Le on 8/8/20.
//

import UIKit

public class CurvedLiner {
    public var lineStyle: LineStyle = LineStyle() {
        didSet {
            drawLine()
        }
    }
    public var anchorStyle: AnchorStyle = AnchorStyle() {
        didSet {
            drawLine()
        }
    }
    public let bezierPath: UIBezierPath
    public var anchorPoints: [CGPoint]
    public lazy var shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = bezierPath.cgPath
        layer.lineWidth = lineStyle.width
        layer.strokeColor = lineStyle.color.cgColor
        layer.fillColor = .none
        layer.lineCap = .round
        return layer
    }()
    public var anchorViews: [UIView]
    public weak var view: UIView?

    public init() {
        anchorPoints = []
        anchorViews = []
        bezierPath = UIBezierPath()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func draw(on view: UIView, with points: [CGPoint]) {
        self.view = view
        self.anchorPoints = points
        view.layer.addSublayer(shapeLayer)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnLine(gesture:)))
        view.addGestureRecognizer(tapGesture)
        drawAnchorPoints()
        drawLine()
    }
}

// MARK: - Privates

extension CurvedLiner {
    private func drawLine() {
        let config = CurvedLineBezierConfiguration()
        let controlPoints = config.configureControlPoints(data: anchorPoints)
        bezierPath.removeAllPoints()
        for i in 0..<anchorPoints.count {
            let point = anchorPoints[i]
            if i == 0 {
                bezierPath.move(to: point)
            } else {
                let segment = controlPoints[i - 1]
                bezierPath.addCurve(to: point, controlPoint1: segment.firstControlPoint,
                                    controlPoint2: segment.secondControlPoint)
            }
        }
        shapeLayer.path = bezierPath.cgPath
    }

    private func drawAnchorPoints() {
        anchorViews.forEach { $0.removeFromSuperview() }

        for (index, point) in anchorPoints.enumerated() {
            let anchorView = UIView()
            anchorView.bounds = CGRect(origin: .zero, size: anchorStyle.size)
            anchorView.backgroundColor = anchorStyle.backgroundColor
            anchorView.layer.cornerRadius = anchorStyle.cornerRadius
            anchorView.layer.borderWidth = anchorStyle.borderWidth
            anchorView.layer.borderColor = anchorStyle.borderColor.cgColor
            anchorView.center = point
            anchorView.tag = index
            view?.addSubview(anchorView)
            let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(dragAnchorView(gesture:)))
            anchorView.addGestureRecognizer(dragGesture)
            anchorViews.append(anchorView)
        }
    }

    @objc func dragAnchorView(gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let newPoint = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        view.center = newPoint
        gesture.setTranslation(.zero, in: view)
        let pointIndex = view.tag
        anchorPoints[pointIndex] = newPoint
        drawLine()
    }

    @objc func tapOnLine(gesture: UITapGestureRecognizer) {
        guard let view = view else { return }
        let point = gesture.location(in: view)
        let isHit = bezierPath.contains(point) || containsPoint(point, path: bezierPath, inFillArea: false)

        if isHit {
            var minTriangle: CGFloat = 0
            var index = 0
            for i in 0..<anchorPoints.count-1 {
                let p0 = anchorPoints[i]
                let p1 = anchorPoints[i + 1]
                let triangle = abs(p0.x * (point.y - p1.y) + point.x * (p1.y - p0.y) + p1.x * (p0.y - point.y))
                if i == 0 {
                    minTriangle = triangle
                    index = i + 1
                } else {
                    if triangle < minTriangle {
                        minTriangle = triangle
                        index = i + 1
                    }
                }
            }
            anchorPoints.insert(point, at: index)
            drawAnchorPoints()
            drawLine()
        }
    }

    private func containsPoint(_ point: CGPoint, path: UIBezierPath, inFillArea: Bool) -> Bool {
        guard let view = view else { return false }
        UIGraphicsBeginImageContext(view.bounds.size)
        let context = UIGraphicsGetCurrentContext()
        let pathToTest = path.cgPath
        var isHit = false
        var mode: CGPathDrawingMode = CGPathDrawingMode.stroke
        if inFillArea {
            if path.usesEvenOddFillRule {
                mode = CGPathDrawingMode.eoFill
            } else {
                mode = CGPathDrawingMode.fill
            }
        }
        context?.saveGState()
        context?.addPath(pathToTest)
        isHit = (context?.pathContains(point, mode: mode)) ?? false
        context?.restoreGState()
        return isHit
    }
}

// MARK: - Models

public struct LineStyle {
    public var color: UIColor = .black
    public var width: CGFloat = 4
}

public struct AnchorStyle {
    public var size = CGSize(width: 15, height: 15)
    public var backgroundColor: UIColor = .white
    public var cornerRadius: CGFloat = 7.5
    public var borderWidth: CGFloat = 3
    public var borderColor: UIColor = .black
}

// MARK: - BezierSegmentControlPoints

private struct BezierSegmentControlPoints {
    var firstControlPoint: CGPoint
    var secondControlPoint: CGPoint
}

// MARK: - BezierConfiguration

private final class CurvedLineBezierConfiguration {
    var firstControlPoints: [CGPoint?] = []
    var secondControlPoints: [CGPoint?] = []

    func configureControlPoints(data: [CGPoint]) -> [BezierSegmentControlPoints] {
        let segments = data.count - 1
        if segments == 1 {
            // straight line calculation here
            let p0 = data[0]
            let p3 = data[1]
            return [BezierSegmentControlPoints(firstControlPoint: p0, secondControlPoint: p3)]
        } else if segments > 1 {
            //left hand side coefficients
            var ad = [CGFloat]()
            var bd = [CGFloat]()
            var d = [CGFloat]()

            var rhsArray = [CGPoint]()

            for i in 0..<segments {

                var rhsX : CGFloat = 0
                var rhsY : CGFloat = 0

                let p0 = data[i]
                let p3 = data[i+1]

                if i == 0 {
                    bd.append(0.0)
                    d.append(2.0)
                    ad.append(1.0)

                    rhsX = p0.x + 2*p3.x
                    rhsY = p0.y + 2*p3.y

                } else if i == segments - 1 {
                    bd.append(2.0)
                    d.append(7.0)
                    ad.append(0.0)

                    rhsX = 8*p0.x + p3.x
                    rhsY = 8*p0.y + p3.y
                } else {
                    bd.append(1.0)
                    d.append(4.0)
                    ad.append(1.0)

                    rhsX = 4*p0.x + 2*p3.x
                    rhsY = 4*p0.y + 2*p3.y
                }

                rhsArray.append(CGPoint(x: rhsX, y: rhsY))

            }

            let solution1 = thomasAlgorithm(bd: bd, d: d, ad: ad, rhsArray: rhsArray, segments: segments, data: data)

            return solution1
        }

        return []
    }

    func thomasAlgorithm(bd: [CGFloat], d: [CGFloat], ad: [CGFloat],
                         rhsArray: [CGPoint], segments: Int,
                         data: [CGPoint]) -> [BezierSegmentControlPoints] {

        var controlPoints : [BezierSegmentControlPoints] = []
        var ad = ad
        let bd = bd
        let d = d
        var rhsArray = rhsArray
        let segments = segments

        var solutionSet1 = [CGPoint?]()
        solutionSet1 = Array(repeating: nil, count: segments)

        //First segment
        ad[0] = ad[0] / d[0]
        rhsArray[0].x = rhsArray[0].x / d[0]
        rhsArray[0].y = rhsArray[0].y / d[0]

        //Middle Elements
        if segments > 2 {
            for i in 1...segments - 2  {
                let rhsValueX = rhsArray[i].x
                let prevRhsValueX = rhsArray[i - 1].x

                let rhsValueY = rhsArray[i].y
                let prevRhsValueY = rhsArray[i - 1].y

                ad[i] = ad[i] / (d[i] - bd[i]*ad[i-1]);

                let exp1x = (rhsValueX - (bd[i]*prevRhsValueX))
                let exp1y = (rhsValueY - (bd[i]*prevRhsValueY))
                let exp2 = (d[i] - bd[i]*ad[i-1])

                rhsArray[i].x = exp1x / exp2
                rhsArray[i].y = exp1y / exp2
            }
        }

        //Last Element
        let lastElementIndex = segments - 1
        let exp1 = (rhsArray[lastElementIndex].x - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].x)
        let exp1y = (rhsArray[lastElementIndex].y - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].y)
        let exp2 = (d[lastElementIndex] - bd[lastElementIndex] * ad[lastElementIndex - 1])
        rhsArray[lastElementIndex].x = exp1 / exp2
        rhsArray[lastElementIndex].y = exp1y / exp2

        solutionSet1[lastElementIndex] = rhsArray[lastElementIndex]

        for i in (0..<lastElementIndex).reversed() {
            let controlPointX = rhsArray[i].x - (ad[i] * solutionSet1[i + 1]!.x)
            let controlPointY = rhsArray[i].y - (ad[i] * solutionSet1[i + 1]!.y)

            solutionSet1[i] = CGPoint(x: controlPointX, y: controlPointY)
        }

        firstControlPoints = solutionSet1

        for i in (0..<segments) {
            if i == (segments - 1) {

                let lastDataPoint = data[i + 1]
                let p1 = firstControlPoints[i]
                guard let controlPoint1 = p1 else { continue }

                let controlPoint2X = (0.5)*(lastDataPoint.x + controlPoint1.x)
                let controlPoint2y = (0.5)*(lastDataPoint.y + controlPoint1.y)

                let controlPoint2 = CGPoint(x: controlPoint2X, y: controlPoint2y)
                secondControlPoints.append(controlPoint2)
            } else {

                let dataPoint = data[i+1]
                let p1 = firstControlPoints[i+1]
                guard let controlPoint1 = p1 else { continue }

                let controlPoint2X = 2*dataPoint.x - controlPoint1.x
                let controlPoint2Y = 2*dataPoint.y - controlPoint1.y

                secondControlPoints.append(CGPoint(x: controlPoint2X, y: controlPoint2Y))
            }
        }

        for i in 0..<segments {
            guard let firstCP = firstControlPoints[i],
                  let secondCP = secondControlPoints[i] else { continue }

            let segmentControlPoint = BezierSegmentControlPoints(firstControlPoint: firstCP, secondControlPoint: secondCP)
            controlPoints.append(segmentControlPoint)
        }

        return controlPoints
    }
}

// MAKR: - RectangleView

public class RectangleView: UIView {
    public var edgeSize: CGFloat = 44.0
    enum Edge {
        case topLeft, topRight, bottomLeft, bottomRight, center
    }
    var currentEdge: Edge = .center
    var touchStart = CGPoint.zero

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {

            touchStart = touch.location(in: self)

            currentEdge = {
                if self.bounds.size.width - touchStart.x < edgeSize && self.bounds.size.height - touchStart.y < edgeSize {
                    return .bottomRight
                } else if touchStart.x < edgeSize && touchStart.y < edgeSize {
                    return .topLeft
                } else if self.bounds.size.width-touchStart.x < edgeSize && touchStart.y < edgeSize {
                    return .topRight
                } else if touchStart.x < edgeSize && self.bounds.size.height - touchStart.y < edgeSize {
                    return .bottomLeft
                }
                return .center
            }()
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let currentPoint = touch.location(in: self)
            let previous = touch.previousLocation(in: self)

            let originX = frame.origin.x
            let originY = frame.origin.y
            let width = frame.size.width
            let height = frame.size.height

            let deltaWidth = currentPoint.x - previous.x
            let deltaHeight = currentPoint.y - previous.y

            switch currentEdge {
            case .topLeft:
                frame = CGRect(x: originX + deltaWidth, y: originY + deltaHeight,
                               width: width - deltaWidth, height: height - deltaHeight)
            case .topRight:
                frame = CGRect(x: originX, y: originY + deltaHeight,
                               width: width + deltaWidth, height: height - deltaHeight)
            case .bottomRight:
                frame = CGRect(x: originX, y: originY,
                               width: width + deltaWidth, height: height + deltaWidth)
            case .bottomLeft:
                frame = CGRect(x: originX + deltaWidth, y: originY,
                               width: width - deltaWidth, height: height + deltaHeight)
            case .center:
                center = CGPoint(x: center.x + currentPoint.x - touchStart.x,
                                 y: center.y + currentPoint.y - touchStart.y)
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentEdge = .center
    }
}

// MARK: - OvalView

public class OvalView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ rect: CGRect) {
        let ovalPath = UIBezierPath(ovalIn: bounds)
        UIColor.gray.setFill()
        ovalPath.fill()
    }

    enum Edge {
        case top, right, bottom, left, center
    }
    var edgeSize: CGFloat = 44.0
    var currentEdge: Edge = .center
    var touchStart = CGPoint.zero

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {

            touchStart = touch.location(in: self)

            currentEdge = {
                if (bounds.size.width/2 - touchStart.x) < edgeSize
                    && (bounds.size.height - touchStart.y) < edgeSize {
                    return .bottom
                } else if (bounds.size.width/2 - touchStart.x) < edgeSize && touchStart.y < edgeSize {
                    return .top
                } else if (bounds.size.width - touchStart.x) < edgeSize && (bounds.size.height/2 - touchStart.y) < edgeSize {
                    return .right
                } else if touchStart.x < edgeSize && (bounds.size.height/2 - touchStart.y) < edgeSize {
                    return .left
                }
                return .center
            }()
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let currentPoint = touch.location(in: self)
            let previous = touch.previousLocation(in: self)

            let originX = frame.origin.x
            let originY = frame.origin.y
            let width = frame.size.width
            let height = frame.size.height

            let deltaWidth = currentPoint.x - previous.x
            let deltaHeight = currentPoint.y - previous.y

            switch currentEdge {
            case .left:
                frame = CGRect(x: originX + deltaWidth, y: originY,
                               width: width - deltaWidth, height: height)
            case .right:
                frame = CGRect(x: originX, y: originY,
                               width: width + deltaWidth, height: height)
            case .top:
                frame = CGRect(x: originX, y: originY + deltaHeight,
                               width: width, height: height - deltaHeight)
            case .bottom:
                frame = CGRect(x: originX, y: originY,
                               width: width, height: height + deltaHeight)
            case .center:
                center = CGPoint(x: center.x + currentPoint.x - touchStart.x,
                                 y: center.y + currentPoint.y - touchStart.y)
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentEdge = .center
    }
}

