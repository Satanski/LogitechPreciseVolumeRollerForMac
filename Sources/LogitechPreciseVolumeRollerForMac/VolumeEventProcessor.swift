import Foundation

public class VolumeEventProcessor {
    // Debounce
    private var lastEventTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.03

    // Direction Lock
    private var lastDirection: Bool? = nil
    private var lastDirectionTime: TimeInterval = 0
    private let directionLockWindow: TimeInterval = 0.30
    private var pendingNewDirectionCount = 0
    private let directionConfirmCount = 2

    public init() {}

    // Główna funkcja logiczna decydująca, czy event ma być przetworzony (zwraca true)
    // Przyjmuje aktualny czas (currentTime) zamiast sama go generować, co pozwala na pełną
    // deterministyczność i bezbłędne testowanie debouncingu i lagów.
    public func processVolumeEvent(isUp: Bool, currentTime: TimeInterval) -> Bool {
        guard currentTime - lastEventTime > debounceInterval else { return false }

        if let dir = lastDirection, currentTime - lastDirectionTime < directionLockWindow, dir != isUp {
            pendingNewDirectionCount += 1
            if pendingNewDirectionCount <= directionConfirmCount {
                // Jeszcze nie zatwierdzono zmiany kierunku (potrzebujemy `directionConfirmCount` potwierdzeń, 
                // czyli pierwszego eventu niezgodnego + N kolejnych). Ignorujemy ten event,
                // ale NIE chcemy resetować "lastDirection" ani "lastEventTime", by móc
                // zliczać kolejne nadchodzące paczki. Aktualizujemy tylko bieżący lag debouncownika.
                lastEventTime = currentTime
                return false
            }
            // Mamy potwierdzenie, resetujemy licznik
            pendingNewDirectionCount = 0
        } else if lastDirection != nil {
            // Skrolujemy w tym samym kierunku, albo minął czas blokady
            pendingNewDirectionCount = 0
        }

        lastEventTime = currentTime
        lastDirection = isUp
        lastDirectionTime = currentTime

        return true
    }
}
