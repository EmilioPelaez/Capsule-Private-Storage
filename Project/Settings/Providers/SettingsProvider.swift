//
//  SettingsProvider.swift
//  Settings
//
//  Created by Emilio Peláez on 03/04/22.
//

import Shared
import SharedUI
import SwiftUI

struct SettingsProvider: ViewModifier {
	@StateObject var settings = UserSettings()
	
	func body(content: Content) -> some View {
		content
			.environmentObject(settings)
			.environment(\.settingsMaxAttempts, settings.maxAttempts)
			.environment(\.settingsBiometrics, settings.biometrics)
			.environment(\.settingsColumns, settings.columns)
			.environment(\.settingsSort, settings.sort)
			.environment(\.settingsShowDetails, settings.showDetails)
			.environment(\.settingsSound, settings.sound)
			.environment(\.settingsHapticFeedback, settings.hapticFeedback)
	}
}

public extension View {
	func settingsProvider() -> some View {
		modifier(SettingsProvider())
	}
}
