import SwiftUI

// MARK: - 传感器仪表盘视图

struct SensorDashboardView: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 设备姿态卡片
                    AttitudeCard(sensorVM: sensorVM)
                    
                    // 加速度计
                    SensorDataCard(
                        title: "加速度计",
                        icon: "move.3d",
                        color: .blue,
                        sensorVM: sensorVM
                    )
                    
                    // 陀螺仪
                    GyroCard(sensorVM: sensorVM)
                    
                    // 位置信息
                    LocationCard(sensorVM: sensorVM)
                    
                    // 音频级别
                    AudioLevelCard(sensorVM: sensorVM)
                    
                    // 步数
                    StepCountCard(sensorVM: sensorVM)
                    
                    // 权限状态
                    PermissionCard(sensorVM: sensorVM)
                    
                    // 上下文摘要（可发给 AI）
                    ContextSummaryCard(sensorVM: sensorVM)
                }
                .padding()
            }
            .navigationTitle("传感器仪表盘")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sensorVM.requestAllPermissions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

// MARK: - 设备姿态卡片

struct AttitudeCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gyroscope")
                    .foregroundColor(.purple)
                Text("设备姿态")
                    .font(.headline)
                Spacer()
                if let att = sensorVM.attitude {
                    Text(att.orientation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if let att = sensorVM.attitude {
                HStack(spacing: 20) {
                    AttitudeGauge(value: att.roll, label: "Roll", color: .red)
                    AttitudeGauge(value: att.pitch, label: "Pitch", color: .green)
                    AttitudeGauge(value: att.yaw, label: "Yaw", color: .blue)
                }
            } else {
                Text("等待数据...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct AttitudeGauge: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: abs(value) / .pi)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.1f", value * 180 / .pi) + "°")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 传感器数据卡片

struct SensorDataCard: View {
    let title: String
    let icon: String
    let color: Color
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(sensorVM.isDeviceMoving ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(sensorVM.isDeviceMoving ? "移动中" : "静止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let accel = sensorVM.accelerometer {
                VStack(spacing: 8) {
                    DataBar(label: "X", value: accel.x, color: .red, range: -2...2)
                    DataBar(label: "Y", value: accel.y, color: .green, range: -2...2)
                    DataBar(label: "Z", value: accel.z, color: .blue, range: -2...2)
                }
                
                HStack {
                    Text("幅度: \(String(format: "%.2f", accel.magnitude))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct DataBar: View {
    let label: String
    let value: Double
    let color: Color
    let range: ClosedRange<Double>
    
    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .frame(width: 16)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 14)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: normalizedWidth(in: geometry), height: 14)
                }
            }
            .frame(height: 14)
            
            Text(String(format: "%.2f", value))
                .font(.caption)
                .frame(width: 40)
                .foregroundColor(.secondary)
        }
    }
    
    private func normalizedWidth(in geometry: GeometryProxy) -> CGFloat {
        let total = range.upperBound - range.lowerBound
        let normalized = (value - range.lowerBound) / total
        return geometry.size.width * CGFloat(max(0, min(1, normalized)))
    }
}

// MARK: - 陀螺仪卡片

struct GyroCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
                Text("陀螺仪")
                    .font(.headline)
                Spacer()
            }
            
            if let gyro = sensorVM.gyroscope {
                VStack(spacing: 8) {
                    DataBar(label: "X", value: gyro.x, color: .orange, range: -5...5)
                    DataBar(label: "Y", value: gyro.y, color: .orange, range: -5...5)
                    DataBar(label: "Z", value: gyro.z, color: .orange, range: -5...5)
                }
            } else {
                Text("等待数据...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - 位置卡片

struct LocationCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text("GPS 定位")
                    .font(.headline)
                Spacer()
                if let loc = sensorVM.location {
                    Text(String(format: "%.0f km/h", loc.speedKMH))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if let loc = sensorVM.location {
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(icon: "mappin", label: "坐标", value: loc.coordinateString)
                    InfoRow(icon: "mountain.2", label: "海拔", value: String(format: "%.1f m", loc.altitude))
                    InfoRow(icon: "speedometer", label: "速度", value: String(format: "%.1f km/h", loc.speedKMH))
                    InfoRow(icon: "location.north", label: "方向", value: String(format: "%.0f°", sensorVM.heading))
                }
            } else {
                Text("等待定位...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 音频级别卡片

struct AudioLevelCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.pink)
                Text("麦克风音量")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(sensorVM.isMicrophoneActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            VStack(spacing: 8) {
                // 音量条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pink.opacity(0.15))
                            .frame(height: 20)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(sensorVM.audioLevel), height: 20)
                    }
                }
                .frame(height: 20)
                
                Text("级别: \(String(format: "%.1f", sensorVM.audioLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - 步数卡片

struct StepCountCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.teal)
                Text("计步器")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Text("\(sensorVM.stepCount)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.teal)
                
                Text("步")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - 权限卡片

struct PermissionCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.indigo)
                Text("权限状态")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(sensorVM.permissionStatuses.sorted(by: { $0.key < $1.key }), id: \.key) { name, status in
                HStack {
                    Text(name)
                        .font(.caption)
                    Spacer()
                    Text(status.description)
                        .font(.caption)
                        .foregroundColor(statusColor(status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor(status).opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func statusColor(_ status: PermissionStatus) -> Color {
        switch status {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .gray
        }
    }
}

// MARK: - 上下文摘要卡片

struct ContextSummaryCard: View {
    @ObservedObject var sensorVM: SensorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.blue)
                Text("AI 感知上下文")
                    .font(.headline)
                Spacer()
                Button {
                    UIPasteboard.general.string = sensorVM.contextSummary
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
            }
            
            Text(sensorVM.contextSummary.isEmpty ? "暂无传感器数据" : sensorVM.contextSummary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}
