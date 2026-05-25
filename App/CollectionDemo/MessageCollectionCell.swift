//
//  MessageCollectionCell.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import UIKit

final class MessageCollectionCell: UICollectionViewCell {

    static let reuseIdentifier = "MessageCollectionCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textAlignment = .right
        return label
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var lockedHeight: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        setupViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let lockedHeight, bounds.height < lockedHeight {
            contentView.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: lockedHeight)
            contentView.center = CGPoint(x: bounds.width / 2, y: bounds.height + lockedHeight / 2)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(titleLabel)
        bubbleView.addSubview(dateLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        let maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        maxWidthConstraint.priority = .required

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            maxWidthConstraint,

            titleLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
        ])
    }

    func configure(with message: Message) {
        titleLabel.text = message.title
        dateLabel.text = Self.dateFormatter.string(from: message.date)

        if message.isMy {
            bubbleView.backgroundColor = .systemBlue
            titleLabel.textColor = .white
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.8)
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = .systemGray4
            titleLabel.textColor = .label
            dateLabel.textColor = .secondaryLabel
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        dateLabel.text = nil
        lockedHeight = nil
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let width = (superview as? UICollectionView)?.bounds.width ?? layoutAttributes.frame.width
        let targetSize = CGSize(width: width, height: 0)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let height = ceil(size.height)
        layoutAttributes.frame.size = CGSize(width: width, height: height)
        lockedHeight = height
        return layoutAttributes
    }
}
