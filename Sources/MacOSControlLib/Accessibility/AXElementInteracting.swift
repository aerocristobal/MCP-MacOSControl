import Foundation

public protocol AXElementInteracting {
    func performPress(_ ref: AXElementReference) throws
    func perform(_ action: String, on ref: AXElementReference) throws
}
