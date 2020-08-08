//
//  QuadrilateralView.swift
//  ShapeDrawer
//
//  Created by Tai Le on 8/8/20.
//

import UIKit

public class QuadrilateralView: UIView {
    public var borderStyle: LineStyle = LineStyle() {
        didSet {
            setNeedsDisplay()
        }
    }
    public var anchorStyle: AnchorStyle = AnchorStyle() {
        didSet {
            setNeedsDisplay()
        }
    }
    var anchorPoints: [CGPoint]
    let bezierPath: UIBezierPath
    lazy var shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = bezierPath.cgPath
        layer.lineWidth = borderStyle.width
        layer.strokeColor = borderStyle.color.cgColor
        layer.fillColor = .none
        layer.lineCap = .square
        return layer
    }()
    lazy var anchorViews: [UIView] = []

    public override init(frame: CGRect) {
        anchorPoints = [.zero, //top left
                        CGPoint(x: frame.width, y: 0), // top right
                        CGPoint(x: frame.width, y: frame.height), // bottom right
                        CGPoint(x: 0, y: frame.width)] // bottom left
        bezierPath = UIBezierPath()
        super.init(frame: frame)
        layer.addSublayer(shapeLayer)
        addAnchorPoints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        bezierPath.removeAllPoints()
        for i in 0..<anchorPoints.count {
            let point = anchorPoints[i]
            if i == 0 {
                bezierPath.move(to: point)
            } else if i == anchorPoints.count - 1 {
                bezierPath.addLine(to: point)
                bezierPath.close()
            } else {
                bezierPath.addLine(to: point)
            }
        }
        shapeLayer.path = bezierPath.cgPath
    }
}

// MARK: - Private

extension QuadrilateralView {
    private func addAnchorPoints() {
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
            addSubview(anchorView)
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
        switch pointIndex {
        case 0: //top left
            anchorPoints[1].y = newPoint.y
            anchorPoints[3].x = newPoint.x
        case 1: //top right
            anchorPoints[0].y = newPoint.y
            anchorPoints[2].x = newPoint.x
        case 2: //bottom right
            anchorPoints[1].x = newPoint.x
            anchorPoints[3].y = newPoint.y
        case 3: //bottom right
            anchorPoints[0].x = newPoint.x
            anchorPoints[2].y = newPoint.y
        default:
            break
        }
        setNeedsDisplay()
        updateBounds(by: newPoint)
        anchorViews[0].center = anchorPoints[0]
        anchorViews[1].center = anchorPoints[1]
        anchorViews[2].center = anchorPoints[2]
        anchorViews[3].center = anchorPoints[3]
    }

    private func updateBounds(by point: CGPoint) {
        frame.size.width = anchorPoints[2].x
        frame.size.height = anchorPoints[2].y
    }
}
