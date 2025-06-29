//
//MIT License
//
//Copyright © 2025 Cong Le
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//
//  RecapitulationSimulationView.swift
//  Recapitulation
//
//  Created by Cong Le on 6/29/25.
//

import SwiftUI
import Combine

// MARK: - Data Models

/// Represents the distinct types of cells in the corticogenesis simulation.
/// Each type has an associated color for visual identification.
enum CellType: String, Identifiable, CaseIterable {
    case embryonicStemCell = "Embryonic Stem Cell"
    case radialGlia = "Radial Glia Progenitor"
    case cajalRetzius = "Cajal-Retzius Neuron (Layer I)"
    case layerVI_Neuron = "Layer VI Neuron"
    case layerV_Neuron = "Layer V Neuron"
    case layerIV_Neuron = "Layer IV Neuron"
    case layerIII_Neuron = "Layer III Neuron"
    case layerII_Neuron = "Layer II Neuron"

    var id: String { self.rawValue }

    /// Provides a distinct color for each cell type.
    var color: Color {
        switch self {
        case .embryonicStemCell: return .purple
        case .radialGlia: return .gray.opacity(0.5)
        case .cajalRetzius: return .red
        case .layerVI_Neuron: return .blue
        case .layerV_Neuron: return .green
        case .layerIV_Neuron: return .orange
        case .layerIII_Neuron: return .yellow
        case .layerII_Neuron: return .pink
        }
    }
}

/// Represents a single cell within the simulation environment.
/// Conforms to `Identifiable` and `Hashable` for use in SwiftUI `ForEach` loops and animations.
struct SimulatedCell: Identifiable, Hashable {
    let id = UUID()
    let type: CellType

    /// The starting point of the cell, typically in the Ventricular Zone.
    var originPosition: CGPoint
    /// The final destination of the cell within a specific cortical layer.
    var finalPosition: CGPoint

    /// The embryonic day when the cell begins its migration.
    let migrationStartDay: Double
    /// The embryonic day when the cell completes its migration.
    let migrationEndDay: Double
}

/// Defines the properties of a cortical layer in the simulation.
struct CorticalLayer: Identifiable {
    let id: Int
    let name: String
    var formationDayRange: ClosedRange<Double>
    let color: Color
    
    /// The vertical offset used for drawing the layer in the UI.
    var yOffset: CGFloat
}

// MARK: - VewModel

/// Manages the state and logic for the corticogenesis simulation.
/// This `ObservableObject` acts as the "brain" of the simulation, handling the timer,
/// cell generation, and state updates, keeping the SwiftUI view clean and declarative.
@MainActor
final class SimulationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var simulationDay: Double = 10.0
    @Published var isPlaying: Bool = false
    @Published var cells: [SimulatedCell] = []
    @Published var currentStage: String = "Preplate Formation"
    
    // MARK: - Simulation Parameters
    
    let totalDays = 18.0
    private var timerSubscription: AnyCancellable?
    
    // Modern approach: Use a Task for cancellable delays.
    private var updateTask: Task<Void, Never>?

    /// Defines the six cortical layers and their developmental timeline and visual properties.
    let corticalLayers: [CorticalLayer] = [
        .init(id: 1, name: "Layer I (MZ)", formationDayRange: 10.5...12.5, color: CellType.cajalRetzius.color.opacity(0.2), yOffset: 0.15),
        .init(id: 6, name: "Layer VI", formationDayRange: 11.5...14.5, color: CellType.layerVI_Neuron.color.opacity(0.2), yOffset: 0.85),
        .init(id: 5, name: "Layer V", formationDayRange: 11.5...14.5, color: CellType.layerV_Neuron.color.opacity(0.2), yOffset: 0.70),
        .init(id: 4, name: "Layer IV", formationDayRange: 11.5...14.5, color: CellType.layerIV_Neuron.color.opacity(0.2), yOffset: 0.55),
        .init(id: 3, name: "Layer III", formationDayRange: 13.5...16.0, color: CellType.layerIII_Neuron.color.opacity(0.2), yOffset: 0.40),
        .init(id: 2, name: "Layer II", formationDayRange: 13.5...16.0, color: CellType.layerII_Neuron.color.opacity(0.2), yOffset: 0.25),
    ]

    init() {
        resetSimulation()
    }
    
    // MARK: - Simulation Control Methods

    func playPause() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }

    func resetSimulation() {
        stopTimer()
        updateTask?.cancel() // Cancel any pending slider update
        isPlaying = false
        simulationDay = 10.0
        cells.removeAll()
        setupInitialState()
        updateSimulationStage()
    }

    /// This function is throttled to prevent excessive updates when scrubbing the slider.
    /// It cancels the previous update task and starts a new one with a short delay.
    func setSimulationDay(_ day: Double) {
        // 1. Cancel the previously scheduled update task.
        updateTask?.cancel()
        
        // 2. Schedule a new update task.
        updateTask = Task {
            do {
                // Sleep for 50 milliseconds (0.05 seconds)
                try await Task.sleep(nanoseconds: 50_000_000)
                
                // This code runs after the delay
                self.simulationDay = day
                regenerateState(upTo: day)
            } catch {
                // This catch block will be entered if the task is cancelled.
                // You can leave it empty if no specific cleanup is needed on cancellation.
            }
        }
    }
    
    // NOTE: The separate `updateDay` function is no longer needed with this modern approach.

    // MARK: - Simulation Logic
    
    // ... (The rest of the `SimulationViewModel` remains the same) ...
    
    /// Sets up the initial state with progenitor cells and Cajal-Retzius cells.
    private func setupInitialState() {
        // Add a field of radial glia progenitors in the Ventricular Zone (bottom).
        for _ in 0..<15 {
            let xPos = CGFloat.random(in: 0.1...0.9)
            cells.append(SimulatedCell(
                type: .radialGlia,
                originPosition: CGPoint(x: xPos, y: 1.0),
                finalPosition: CGPoint(x: xPos, y: 0.05), // Stretch to the pia
                migrationStartDay: 10.0,
                migrationEndDay: 10.5
            ))
        }
        
        // Add Cajal-Retzius cells to form the preplate/marginal zone (Layer I).
        generateCells(ofType: .cajalRetzius, count: 8, day: 10.5)
    }
    
    /// Regenerates the entire cell state up to a specific day.
    /// Used by the slider to show the correct state at any point in time.
    private func regenerateState(upTo day: Double) {
        cells.removeAll()
        setupInitialState()
        
        // Sequentially generate cells for each layer if the simulation day has passed their formation start.
        if day > 11.5 { generateCells(ofType: .layerVI_Neuron, count: 12, day: 11.5) }
        if day > 12.0 { generateCells(ofType: .layerV_Neuron, count: 12, day: 12.0) }
        if day > 12.5 { generateCells(ofType: .layerIV_Neuron, count: 12, day: 12.5) }
        if day > 13.5 { generateCells(ofType: .layerIII_Neuron, count: 12, day: 13.5) }
        if day > 14.0 { generateCells(ofType: .layerII_Neuron, count: 12, day: 14.0) }
        
        updateSimulationStage()
    }
    
    /// The main simulation loop, called by the timer.
    private func advanceTime() {
        guard simulationDay < totalDays else {
            playPause() // Stop when done
            return
        }
        
        simulationDay += 0.05
        
        // Check if it's time to generate new cells for a layer.
        switch simulationDay {
        case 11.5..<11.55: generateCells(ofType: .layerVI_Neuron, count: 12, day: 11.5)
        case 12.0..<12.05: generateCells(ofType: .layerV_Neuron, count: 12, day: 12.0)
        case 12.5..<12.55: generateCells(ofType: .layerIV_Neuron, count: 12, day: 12.5)
        case 13.5..<13.55: generateCells(ofType: .layerIII_Neuron, count: 12, day: 13.5)
        case 14.0..<14.05: generateCells(ofType: .layerII_Neuron, count: 12, day: 14.0)
        default: break
        }
        
        updateSimulationStage()
    }

    /// Generates a new batch of cells of a specific type.
    private func generateCells(ofType type: CellType, count: Int, day: Double) {
        guard let layer = corticalLayers.first(where: { $0.name.contains(type.rawValue.split(separator: " ").first!) }) else { return }

        for _ in 0..<count {
            let originX = CGFloat.random(in: 0.1...0.9)
            let finalX = originX + CGFloat.random(in: -0.05...0.05) // Slight horizontal drift
            
            let newCell = SimulatedCell(
                type: type,
                originPosition: CGPoint(x: originX, y: 1.0), // Start in Ventricular Zone
                finalPosition: CGPoint(x: finalX, y: layer.yOffset),
                migrationStartDay: day,
                migrationEndDay: day + Double.random(in: 2.0...3.0) // Migration takes time
            )
            cells.append(newCell)
        }
    }
    
    private func updateSimulationStage() {
        if simulationDay < 11.5 {
            currentStage = "Preplate & Layer I Formation"
        } else if simulationDay < 13.5 {
            currentStage = "Deep Layer Formation (VI, V, IV)"
        } else if simulationDay < 16.0 {
            currentStage = "Superficial Layer Formation (III, II)"
        } else {
            currentStage = "Synaptic Refinement & Maturation"
        }
    }
    
    // MARK: - Timer Handling
    private func startTimer() {
        timerSubscription = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.advanceTime()
            }
    }

    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
}
// MARK: - SwiftUI Views

/// The main view that encapsulates the entire simulation interface.
struct RecapitulationSimulationView: View {
    @StateObject private var viewModel = SimulationViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Recapitulation of Corticogenesis")
                .font(.title).bold()
                .foregroundColor(.primary)
            Text("Simulating ESC self-organization into cortical layers in vitro.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // The main simulation display area.
            CultureDishView(viewModel: viewModel)
                .padding(.horizontal)

            // Information panel showing the current state of the simulation.
            VStack {
                Text(String(format: "Embryonic Day: %.2f", viewModel.simulationDay))
                    .font(.headline)
                Text("Stage: \(viewModel.currentStage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // User controls for interacting with the simulation.
            SimulationControls(viewModel: viewModel)

            // A legend to explain the color coding of the cell types.
            LegendView()
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear(perform: viewModel.resetSimulation)
    }
}

/// The visual representation of the "culture dish" where the simulation occurs.
struct CultureDishView: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background representing the culture medium.
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                
                // Visual representation of the cortical zones and layers.
                drawZones(in: geometry.size)
                
                // Draw all the simulated cells.
                drawCells(in: geometry.size)
                
                // Draw zone labels.
                drawZoneLabels(in: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .aspectRatio(1.0, contentMode: .fit)
    }

    /// Draws the background rectangles for each cortical layer.
    @ViewBuilder
    private func drawZones(in size: CGSize) -> some View {
        ZStack(alignment: .top) {
            // Ventricular Zone (VZ), where progenitors reside.
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: size.height * 0.1)
                .offset(y: size.height * 0.9)
            
            // The layers of the cortical plate.
            ForEach(viewModel.corticalLayers) { layer in
                let isFormed = viewModel.simulationDay >= layer.formationDayRange.lowerBound
                Rectangle()
                    .fill(layer.color)
                    .frame(height: size.height * 0.15) // Each layer gets a band
                    .offset(y: size.height * (layer.yOffset - 0.075))
                    .opacity(isFormed ? 1.0 : 0.0)
            }
        }
    }
    
    /// Renders each cell at its calculated position for the current simulation day.
    @ViewBuilder
    private func drawCells(in size: CGSize) -> some View {
        ForEach(viewModel.cells) { cell in
            Circle()
                .fill(cell.type.color)
                .frame(width: cell.type == .radialGlia ? 4 : 8, height: cell.type == .radialGlia ? 4 : 8)
                .position(calculatePosition(for: cell, in: size))
                .shadow(color: cell.type.color, radius: 2)
                .id(cell.id) // Ensure SwiftUI tracks each cell individually
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.simulationDay)
    }
    
    /// Draws labels for the key developmental zones.
    @ViewBuilder
    private func drawZoneLabels(in size: CGSize) -> some View {
        Text("Marginal Zone (Pia)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .position(x: size.width * 0.5, y: size.height * 0.03)
            
        Text("Cortical Plate")
            .font(.caption2)
            .foregroundColor(.secondary)
            .position(x: size.width * 0.5, y: size.height * 0.5)
        
        Text("Ventricular Zone (VZ)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .position(x: size.width * 0.5, y: size.height * 0.97)
    }

    /// Calculates the current position of a cell by interpolating between its origin and destination.
    /// This function is the core of the migration animation.
    private func calculatePosition(for cell: SimulatedCell, in size: CGSize) -> CGPoint {
        let progress: CGFloat
        
        if viewModel.simulationDay <= cell.migrationStartDay {
            progress = 0.0
        } else if viewModel.simulationDay >= cell.migrationEndDay {
            progress = 1.0
        } else {
            let duration = cell.migrationEndDay - cell.migrationStartDay
            progress = (viewModel.simulationDay - cell.migrationStartDay) / duration
        }

        // Linear interpolation (lerp) for x and y coordinates.
        let currentX = cell.originPosition.x + (cell.finalPosition.x - cell.originPosition.x) * progress
        let currentY = cell.originPosition.y + (cell.finalPosition.y - cell.originPosition.y) * progress
        
        return CGPoint(x: currentX * size.width, y: currentY * size.height)
    }
}

/// A view containing the Play, Pause, Reset buttons and the simulation timeline slider.
struct SimulationControls: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                Button(action: viewModel.playPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 50, height: 50)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Button(action: viewModel.resetSimulation) {
                    Image(systemName: "arrow.counter.clockwise")
                        .font(.title)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            Slider(
                value: $viewModel.simulationDay,
                in: 10.0...viewModel.totalDays,
                step: 0.05,
                onEditingChanged: { editing in
                    if !editing {
                        // When slider interaction ends, regenerate the state for that day.
                        viewModel.setSimulationDay(viewModel.simulationDay)
                    }
                }
            )
            .padding(.horizontal)
        }
    }
}

/// A view that displays a legend for the cell type colors.
struct LegendView: View {
    let cellTypes = CellType.allCases
    private let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Legend").font(.headline).padding(.bottom, 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(cellTypes) { type in
                    HStack {
                        Circle()
                            .fill(type.color)
                            .frame(width: 10, height: 10)
                        Text(type.rawValue)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider

struct RecapitulationSimulationView_Previews: PreviewProvider {
    static var previews: some View {
        RecapitulationSimulationView()
    }
}
