//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMKPageScoreLayout.h"
#import "VMKGeometry.h"


using namespace mxml;

static const CGFloat kCursorWidth = 16;
static const CGFloat kBottomPadding = 40;


@implementation VMKPageScoreLayout

- (instancetype)init {
    self = [super init];
    self.scale = 1;
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)decoder {
    self = [super initWithCoder:decoder];
    self.scale = 1;
    return self;
}

- (void)setScoreGeometry:(const mxml::PageScoreGeometry*)scoreGeometry {
    _scoreGeometry = scoreGeometry;
    [self invalidateLayout];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

- (NSArray*)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray* attributesArray = [NSMutableArray array];

    // Header
    if (rect.origin.y < self.headerHeight) {
        [attributesArray addObject:[self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
    }

    if (!_scoreGeometry)
        return attributesArray;

    // Systems
    const auto systemCount = _scoreGeometry->systemGeometries().size();
    for (NSUInteger systemIndex = 0; systemIndex < systemCount; systemIndex += 1) {
        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:systemIndex inSection:0];

        auto systemGeometry = _scoreGeometry->systemGeometries()[systemIndex];
        UICollectionViewLayoutAttributes* attributes = [self layoutAttributesForGeometry:systemGeometry atIndexPath:indexPath];
        if (CGRectIntersectsRect(rect, attributes.frame))
            [attributesArray addObject:attributes];
    }

    // Cursors
    if (self.cursorStyle == VMKCursorStyleNote) {
        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:0 inSection:1];
        [attributesArray addObject:[self layoutAttributesForCursorAtIndexPath:indexPath]];
    } else if (self.cursorStyle == VMKCursorStyleMeasure) {
        [attributesArray addObjectsFromArray:[self layoutAttributesForMeasureCursors]];
    }

    return attributesArray;
}

- (UICollectionViewLayoutAttributes*)layoutAttributesForItemAtIndexPath:(NSIndexPath*)indexPath {
    if (indexPath.section == 0)
        return [self layoutAttributesForCursorAtIndexPath:indexPath];

    auto systemGeometry = static_cast<const SystemGeometry*>(_scoreGeometry->systemGeometries()[indexPath.item]);
    return [self layoutAttributesForGeometry:systemGeometry atIndexPath:indexPath];
}

- (UICollectionViewLayoutAttributes*)layoutAttributesForCursorAtIndexPath:(NSIndexPath*)indexPath {
    auto cursorLocation = [self cursorNoteLocation];

    CGRect frame;
    frame.origin.x = cursorLocation.x - kCursorWidth/2;
    frame.origin.y = cursorLocation.y;
    frame.size.width = kCursorWidth;

    std::size_t systemIndex = 0;
    if (self.cursorEvent)
        systemIndex = _scoreGeometry->scoreProperties().systemIndex(self.cursorEvent->measureIndex());

    auto& systemGeometries = _scoreGeometry->systemGeometries();
    if (systemIndex >= systemGeometries.size())
        systemIndex = systemGeometries.size() - 1;
    frame.size.height = systemGeometries.at(systemIndex)->size().height;

    const CGAffineTransform transform = CGAffineTransformMakeScale(self.scale, self.scale);
    frame = CGRectApplyAffineTransform(frame, transform);
    frame.origin.y += self.headerHeight;

    UICollectionViewLayoutAttributes* attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = frame;
    attributes.alpha = 1;
    attributes.zIndex = 1;

    return attributes;
}

- (NSArray*)layoutAttributesForMeasureCursors {
    NSMutableArray* attributesArray = [NSMutableArray array];
    if (!self.cursorEvent)
        return nullptr;

    const auto& scoreProperties = _scoreGeometry->scoreProperties();
    const auto& event = *self.cursorEvent;
    const auto measureIndex = event.measureIndex();
    const auto systemIndex = scoreProperties.systemIndex(measureIndex);
    const auto range = scoreProperties.measureRange(systemIndex);
    const auto systemGeometry = _scoreGeometry->systemGeometries()[systemIndex];

    NSUInteger item = 0;
    for (std::size_t partIndex = 0; partIndex < scoreProperties.partCount(); partIndex += 1) {
        const auto staves = scoreProperties.staves(partIndex);

        auto partGeometry = systemGeometry->partGeometries()[partIndex];
        auto measureGeometry = partGeometry->measureGeometries()[measureIndex - range.first];

        for (int staff = 1; staff <= staves; staff += 1) {
            CGRect frame = CGRectFromRect(partGeometry->convertToGeometry(measureGeometry->frame(), _scoreGeometry));
            frame.origin.y += mxml::MeasureGeometry::kVerticalPadding + partGeometry->staffOrigin(staff);
            frame.size.height = Metrics::staffHeight();

            const CGAffineTransform transform = CGAffineTransformMakeScale(self.scale, self.scale);
            frame = CGRectApplyAffineTransform(frame, transform);
            frame.origin.y += self.headerHeight;

            NSIndexPath* indexPath = [NSIndexPath indexPathForItem:item inSection:1];
            item += 1;

            UICollectionViewLayoutAttributes* attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            attributes.frame = frame;
            attributes.alpha = 1;
            attributes.zIndex = -1;
            
            [attributesArray addObject:attributes];
        }
    }

    return attributesArray;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForGeometry:(const mxml::Geometry*)geometry atIndexPath:(NSIndexPath *)indexPath {
    const CGAffineTransform transform = CGAffineTransformMakeScale(self.scale, self.scale);
    CGRect frame = CGRectFromRect(_scoreGeometry->convertFromGeometry(geometry->frame(), geometry->parentGeometry()));
    frame = VMKRoundRect(frame);
    frame = CGRectApplyAffineTransform(frame, transform);
    frame.origin.y += self.headerHeight;

    UICollectionViewLayoutAttributes* attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = frame;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (![kind isEqualToString:UICollectionElementKindSectionHeader])
        return nil;
    
    UICollectionViewLayoutAttributes* attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:kind withIndexPath:indexPath];
    attributes.frame = CGRectMake(0, 0, _scoreGeometry->size().width * self.scale, self.headerHeight);
    return attributes;
}

- (CGSize)collectionViewContentSize {
    if (!_scoreGeometry)
        return CGSizeZero;

    CGSize size = CGSizeMake(_scoreGeometry->size().width, _scoreGeometry->size().height);
    const CGAffineTransform transform = CGAffineTransformMakeScale(self.scale, self.scale);
    size = CGSizeApplyAffineTransform(size, transform);
    size.height += self.headerHeight + kBottomPadding;
    return size;
}


#pragma mark - Cursor positioning

- (CGPoint)cursorNoteLocation {
    if (!self.cursorEvent)
        return CGPointFromPoint(_scoreGeometry->origin());

    const auto& event = *self.cursorEvent;
    const auto& scoreProperties = _scoreGeometry->scoreProperties();
    const auto& spans = _scoreGeometry->spans();

    auto it = spans.closest(event.measureIndex(), event.measureTime(), typeid(mxml::dom::Note));
    if (it != spans.end()) {
        auto& span = *it;
        auto systemIndex = scoreProperties.systemIndex(span.measureIndex());
        auto range = scoreProperties.measureRange(systemIndex);
        auto systemGeometry = _scoreGeometry->systemGeometries()[systemIndex];

        CGPoint location;
        location.x = span.start() - spans.origin(range.first) + span.eventOffset();
        location.y = systemGeometry->origin().y;
        return location;
    }

    return CGPointFromPoint(_scoreGeometry->origin());
}

@end
