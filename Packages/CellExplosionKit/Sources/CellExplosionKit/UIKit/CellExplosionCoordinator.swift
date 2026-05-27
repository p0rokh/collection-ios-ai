import UIKit
import QuartzCore

/// Центральный оркестратор эффекта взрыва ячейки и коллапса высоты.
///
/// `CellExplosionCoordinator` связывает layout-контроллер, snapshot-провайдер
/// и renderer в один объект. Потребитель создаёт его один раз и держит живым
/// на всё время жизни collection view. Координатор выступает как
/// `CellCollapseLayoutControllerDelegate`, перехватывает пакеты удалений, захватывает
/// snapshot ячеек, запускает анимации `CollapseTracker` и управляет циклом
/// `CADisplayLink`, взрывая частицы в момент, когда видимая высота ячейки
/// опускается ниже `configuration.burstThreshold`.
///
/// **Типовая настройка:**
/// ```swift
/// let renderer = SpriteKitParticleRenderer(configuration: .default)
/// renderer.view.frame = view.bounds
/// view.addSubview(renderer.view)
///
/// let coordinator = CellExplosionCoordinator(
///     collectionView: collectionView,
///     container: view,
///     renderer: renderer,
///     layoutController: collapseController
/// )
/// ```
///
/// После создания стандартные вызовы `collectionView.deleteItems(at:)` автоматически
/// запускают эффект. Изменений в коде удаления не требуется.
///
/// **Отключение эффекта:**
/// Установите `isEnabled = false`, чтобы координатор стал полным no-op. Удаления
/// будут выполняться со стандартной анимацией `UICollectionView`, без захвата snapshot.
///
/// **Выборочное отключение:**
/// Установите `shouldExplode`, возвращающий `false` для конкретных index path.
/// Эти path используют стандартную анимацию удаления, остальные в пакете
/// всё равно взрываются. Например:
/// ```swift
/// coordinator.shouldExplode = { indexPath in indexPath.item != pinnedItemIndex }
/// ```
///
/// **Конфигурация во время выполнения:**
/// Присвоение нового `ExplosionConfiguration` в `configuration` вступает в силу
/// для следующего пакета удалений. Анимации в процессе всегда завершаются с той
/// конфигурацией, которая была активна в момент их запуска.
public final class CellExplosionCoordinator {

    /// Когда `false`, координатор является полным no-op: метод delegate возвращается
    /// немедленно, `markCollapsing` не вызывается, а удаления анимируются
    /// стандартным переходом `UICollectionView`.
    public var isEnabled: Bool = true

    /// Предикат для каждого отдельного path, определяющий, должна ли удалённая ячейка взорваться.
    ///
    /// По умолчанию возвращает `true` для каждого path (все удаления взрываются).
    /// Вернуть `false` для конкретного path, чтобы он использовал стандартную
    /// анимацию удаления, пока остальные в пакете всё равно взрываются. Closure
    /// вызывается синхронно в главном потоке во время `prepare(forCollectionViewUpdates:)`.
    public var shouldExplode: (IndexPath) -> Bool = { _ in true }

    /// Параметры физики и тайминга, применяемые к следующему пакету взрывов.
    public var configuration: ExplosionConfiguration

    /// Источник ячеек по index path. По умолчанию использует `collectionView.cellForItem(at:)`.
    ///
    /// Переопределите в тестах, чтобы предоставлять mock-ячейки без живого collection view.
    /// В рабочем коде значение по умолчанию достаточно; свойство публично исключительно
    /// для удобства интеграционного тестирования.
    public var cellProvider: (IndexPath) -> UICollectionViewCell?

    private weak var collectionView: UICollectionView?
    private weak var container: UIView?
    private let renderer: ParticleRenderer
    private let layoutController: CellCollapseLayoutController
    private let snapshotProvider: CellSnapshotProvider

    struct PendingExplosion {
        let image: UIImage
        let originalFrame: CGRect
        let initialHeight: CGFloat
        // RAII: CALayer tracker-а удаляется из контейнера в его deinit,
        // привязывая время жизни tracker-а к владеющей им записи в pendingExplosions.
        let tracker: CollapseTracker
    }

    private var pendingExplosions: [PendingExplosion] = []
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?

    /// Создаёт координатор и регистрирует его как delegate layout-контроллера.
    ///
    /// Координатор хранит слабые ссылки на `collectionView` и `container`,
    /// поэтому не препятствует освобождению памяти хост-иерархии видов.
    ///
    /// - Parameters:
    ///   - collectionView: Collection view, удаления из которого будут перехватываться.
    ///   - container: Вид, используемый как начало координат для позиций частиц
    ///     и как родитель для слоёв `CollapseTracker`. Как правило — корневой вид
    ///     view controller.
    ///   - renderer: Rendering-бэкенд частиц. Его `view` должен быть добавлен
    ///     в `container` до первых удалений.
    ///   - layoutController: Layout-контроллер, встроенный в flow layout потребителя.
    ///     Координатор устанавливает себя как delegate контроллера.
    ///   - snapshotProvider: Стратегия получения snapshot ячейки. По умолчанию
    ///     `DefaultCellSnapshotProvider`, корректный для неперевёрнутых layout.
    ///   - configuration: Начальные параметры физики и тайминга.
    public init(
        collectionView: UICollectionView,
        container: UIView,
        renderer: ParticleRenderer,
        layoutController: CellCollapseLayoutController,
        snapshotProvider: CellSnapshotProvider = DefaultCellSnapshotProvider(),
        configuration: ExplosionConfiguration = .default
    ) {
        self.collectionView = collectionView
        self.container = container
        self.renderer = renderer
        self.layoutController = layoutController
        self.snapshotProvider = snapshotProvider
        self.configuration = configuration
        self.cellProvider = { [weak collectionView] path in
            collectionView?.cellForItem(at: path)
        }
        layoutController.delegate = self
    }

    deinit {
        displayLink?.invalidate()
    }

    /// Вызывайте после обновления data source. Берёт на себя всю анимацию удаления:
    /// вычисляет тайминги из `configuration`, запускает bounce соседних ячеек,
    /// оборачивает `deleteItems` в `UIView.animate + performBatchUpdates`.
    ///
    /// - Parameter indexPaths: Index path элементов, уже удалённых из data source.
    public func performDeletion(at indexPaths: [IndexPath]) {
        guard let collectionView else { return }

        let totalDuration    = configuration.totalAnimationDuration
        let collapseFraction = configuration.collapseTimingFraction
        let collapseDuration = configuration.collapseDuration

        let minDeletedItem = indexPaths.map(\.item).min() ?? 0
        let deletedSet     = Set(indexPaths)
        let movingCells = collectionView.visibleCells.filter { cell in
            guard let p = collectionView.indexPath(for: cell) else { return false }
            return p.item > minDeletedItem && !deletedSet.contains(p)
        }

        // Bounce запускаем ДО UIView.animate — обе анимации должны стартовать
        // в одном RunLoop-тёрне, иначе bounce окажется позади по времени.
        let bounce            = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values         = [0, 0, 4.0, 0, 0]
        bounce.keyTimes       = [
            0,
            NSNumber(value: collapseFraction),
            NSNumber(value: collapseFraction + 0.10),
            NSNumber(value: collapseFraction + 0.25),
            1,
        ]
        bounce.duration       = totalDuration
        bounce.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
        ]
        for cell in movingCells {
            cell.layer.add(bounce, forKey: "anvil-bounce")
        }

        UIView.animate(
            withDuration: collapseDuration,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                collectionView.performBatchUpdates {
                    collectionView.deleteItems(at: indexPaths)
                }
            },
            completion: nil
        )
    }

    /// Обрабатывает подтверждённый пакет удалений после фильтрации через `isEnabled` и `shouldExplode`.
    ///
    /// Один `CollapseTracker` разделяется на весь пакет, чтобы одна `CABasicAnimation`
    /// синхронно управляла всеми параллельными коллапсами ячеек. Каждая ячейка,
    /// прошедшая проверку snapshot, создаёт запись `PendingExplosion`, а цикл
    /// `CADisplayLink` работает, пока все записи не взорвутся.
    private func handleDeletions(_ paths: [IndexPath]) {
        guard isEnabled, let container else { return }
        let filtered = paths.filter { shouldExplode($0) }
        guard !filtered.isEmpty else { return }

        var ready: [IndexPath] = []
        // Один tracker на пакет: одна CABasicAnimation синхронно управляет всеми
        // параллельными коллапсами в одном пакете удалений.
        let tracker = CollapseTracker(container: container)

        for path in filtered {
            guard let cell = cellProvider(path),
                  let image = snapshotProvider.snapshot(of: cell) else { continue }
            let frameInContainer = cell.convert(cell.bounds, to: container)
            pendingExplosions.append(PendingExplosion(
                image: image,
                originalFrame: frameInContainer,
                initialHeight: cell.bounds.height,
                tracker: tracker
            ))
            ready.append(path)
        }

        guard !ready.isEmpty else { return }
        layoutController.markCollapsing(at: ready)
        tracker.start(duration: configuration.collapseDuration) {}
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        displayLinkProxy = proxy
    }

    fileprivate func handleDisplayLinkTick() {
        processTick(fractionOverride: nil)
    }

    /// Обрабатывает один тик `CADisplayLink`: проверяет каждый ожидающий взрыв,
    /// генерирует частицы и инвалидирует display link, когда все записи обработаны.
    ///
    /// `max(1, currentHeight)` защищает от передачи нулевой высоты в
    /// `cropBottom(of:toPoints:)`, что привело бы к нулевой обрезке и пустому
    /// пакету частиц.
    private func processTick(fractionOverride: CGFloat?) {
        guard !pendingExplosions.isEmpty else {
            invalidateDisplayLink()
            return
        }

        var stillPending: [PendingExplosion] = []
        var allParticles: [Particle] = []

        for entry in pendingExplosions {
            let fraction = fractionOverride ?? entry.tracker.currentFraction()
            let currentHeight = entry.initialHeight * fraction
            if currentHeight <= configuration.burstThreshold {
                // Ограничиваем минимум 1 точкой, чтобы cropBottom никогда не получал
                // нулевую высоту, которая привела бы к пустой (или nil) обрезке.
                let h = max(1, currentHeight)
                let currentFrame = CGRect(
                    x: entry.originalFrame.origin.x,
                    y: entry.originalFrame.maxY - h,
                    width: entry.originalFrame.width,
                    height: h
                )
                if let cropped = snapshotProvider.cropBottom(of: entry.image, toPoints: h),
                   let cg = cropped.cgImage {
                    let parts = ParticleFactory.makeParticles(
                        from: cg,
                        scale: cropped.scale,
                        origin: currentFrame.origin,
                        configuration: configuration
                    )
                    allParticles.append(contentsOf: parts)
                }
            } else {
                stillPending.append(entry)
            }
        }
        pendingExplosions = stillPending

        if !allParticles.isEmpty {
            container?.bringSubviewToFront(renderer.view)
            renderer.addParticles(allParticles)
        }

        if pendingExplosions.isEmpty {
            invalidateDisplayLink()
        }
    }

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }
}

extension CellExplosionCoordinator: CellCollapseLayoutControllerDelegate {
    public func cellCollapseLayoutController(
        _ controller: CellCollapseLayoutController,
        willProcessDeletionsAt indexPaths: [IndexPath]
    ) {
        handleDeletions(indexPaths)
    }
}

/// Разрывает цикл удержания CADisplayLink → coordinator. Runloop держит proxy
/// сильно, но proxy ссылается на coordinator только слабо, поэтому закрытие
/// host view controller в середине анимации освобождает coordinator вовремя
/// (proxy продолжает пересылать no-op тики до следующей инвалидации).
private final class DisplayLinkProxy {
    weak var target: CellExplosionCoordinator?

    init(target: CellExplosionCoordinator) {
        self.target = target
    }

    @objc func tick() {
        target?.handleDisplayLinkTick()
    }
}

#if DEBUG
extension CellExplosionCoordinator {
    var pendingExplosionsForTesting: [PendingExplosion] { pendingExplosions }
    func tickForTesting(fractionOverride: CGFloat) {
        processTick(fractionOverride: fractionOverride)
    }
}
#endif
