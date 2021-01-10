import AppKit
import Metal
import MetalKit

class ViewController : NSViewController, MTKViewDelegate {

  var device: MTLDevice!
  var commandQueue: MTLCommandQueue!
  var pipelineState: MTLRenderPipelineState!
  var computeState: MTLComputePipelineState!
  var vertexBuffer: MTLBuffer?
  var textures = [MTLTexture?](repeating: nil, count: 2)
  var texId: Int = 0
  var sampler: MTLSamplerState?
  let samplerDescriptor = MTLSamplerDescriptor()

  var cellsWide = 1024
  var cellsHigh = 1024
  var frame = 0

  override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
      case 53: // ESC
        NSLog("ESC")
        NSApp.terminate(self)
      case 17: // t
        texId ^= 1
      default:
        print("keyCode is \(event.keyCode)")
    }
  }

  override func flagsChanged(with event: NSEvent) {
    switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
      case [.shift]:
        print("shift key is pressed")
      case [.control]:
        print("control key is pressed")
      default:
        print("no modifier keys are pressed")
    }
  }

  override func loadView() {

    guard let device = MTLCreateSystemDefaultDevice() else {
      print("Metal is not supported on this device")
      return
    }

    print("Metal device: \(device)")

    sampler = device.makeSamplerState(descriptor: samplerDescriptor)
    commandQueue = device.makeCommandQueue()!

    let metalView = MTKView(frame: .zero, device: device)
    metalView.clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1)
    metalView.delegate = self

    self.view = metalView

    // Create a new pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    var library: MTLLibrary?
    do {
      let path = "./shaders.metal"
      let source = try String(contentsOfFile: path, encoding: .utf8)
      library = try device.makeLibrary(source: source, options: nil)
    } catch {
      print("Library error: \(error)")
    }

    pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
    pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")

    // Setup the output pixel format to match the pixel format of the metal kit view
    pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
    do {
      try pipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      print("Unable to compile render pipeline state: \(error)")
    }

    // compute shader
    let computeFn = library!.makeFunction(name: "step")!
    computeState = try! device.makeComputePipelineState(function: computeFn)
    /////////////////

    // Create our vertex data
    let vertices = [
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [-1,  1], tex: [0, 0]),
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [ 1,  1], tex: [1, 0]),
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [-1, -1], tex: [0, 1]),
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [ 1, -1], tex: [1, 1]),
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [-1, -1], tex: [0, 1]),
      Vertex(color: [0.7, 0.7, 0.7, 0.7], pos: [ 1,  1], tex: [1, 0])
    ]

    vertexBuffer = device.makeBuffer(
      bytes: vertices,
      length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!

    //let loader = MTKTextureLoader(device: device)
    //if let url = Bundle.main.url(forResource: "prodos", withExtension: "png") {
    //    if FileManager.default.fileExists(atPath: url.path) {
    //        print("\(url) loaded")
    //        textures[0] = try! loader.newTexture(URL: url, options: nil)
    //    }
    //}

    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
        self.flagsChanged(with: $0)
        return $0
    }

    NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
      self.keyDown(with: $0)
      return $0
    }

    let dst = MTLTextureDescriptor()
    dst.storageMode = .managed
    dst.usage = [.shaderWrite, .shaderRead]
    dst.pixelFormat = .r8Uint
    dst.width = cellsWide
    dst.height = cellsHigh
    dst.depth = 1

    textures[0] = device.makeTexture(descriptor: dst)!
    textures[1] = device.makeTexture(descriptor: dst)!

    var seed = [UInt8](repeating: 0, count: cellsWide * cellsHigh)

      let numberOfCells = cellsWide * cellsHigh
      let numberOfLiveCells = Int(pow(Double(numberOfCells), 0.9))
      for _ in (0..<numberOfLiveCells) {
        let r = (0..<numberOfCells).randomElement()!
        seed[r] = 1
      }

    textures[0]?.replace(
      region: MTLRegionMake2D(0, 0, cellsWide, cellsHigh),
      mipmapLevel: 0,
      withBytes: seed,
      bytesPerRow: cellsWide * MemoryLayout<UInt8>.stride
    )
  }

  // mtkView will automatically call this function
  // whenever the size of the view changes (such as resizing the window)
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    print("new size \(size)")
  }

  // mtkView will automatically call this function
  // whenever it wants new content to be rendered
  func draw(in view: MTKView) {

    // Get an available command buffer
    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
    // Get the default MTLRenderPassDescriptor
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)

    // We compile renderPassDescriptor to a MTLRenderCommandEncoder
    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

    // shader
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderEncoder.setFragmentTexture(textures[texId], index: 0)
    renderEncoder.setFragmentSamplerState(sampler, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    //

    // This finalizes the encoding of drawing commands.
    renderEncoder.endEncoding()

    // Compute shader

    guard
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()
      else { return }

    computeEncoder.setComputePipelineState(computeState)
    computeEncoder.setTexture((frame % 2 == 0) ? textures[0] : textures[1], index: 0)
    computeEncoder.setTexture((frame % 2 == 0) ? textures[1] : textures[0], index: 1)
    let threadWidth = computeState.threadExecutionWidth
    let threadHeight = computeState.maxTotalThreadsPerThreadgroup / threadWidth
    let threadsPerThreadgroup = MTLSizeMake(threadWidth, threadHeight, 1)
    let threadsPerGrid = MTLSizeMake(cellsWide, cellsHigh, 1)
    computeEncoder.dispatchThreads(threadsPerGrid,
      threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder.endEncoding()
    // end compute shader

    // Tell Metal to send the rendering result to the MTKView when rendering completes
    if let drawable = view.currentDrawable {
      commandBuffer.present(drawable)
    }

    // Finally, send the encoded command buffer to the GPU.
    commandBuffer.commit()
    frame += 1
    print(frame)
  }

}
