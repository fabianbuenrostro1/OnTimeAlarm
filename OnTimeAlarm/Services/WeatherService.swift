import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

struct WeatherService {

    // MARK: - Weather Info Model

    struct WeatherInfo {
        let temperature: Measurement<UnitTemperature>
        let condition: WeatherCondition
        let symbolName: String
        let conditionDescription: String
        let suggestion: String?

        var formattedTemperature: String {
            let formatter = MeasurementFormatter()
            formatter.unitStyle = .short
            formatter.numberFormatter.maximumFractionDigits = 0
            return formatter.string(from: temperature)
        }
    }

    enum WeatherCondition {
        case clear
        case cloudy
        case partlyCloudy
        case rain
        case snow
        case fog
        case windy
        case thunderstorm
        case unknown

        var icon: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .partlyCloudy: return "cloud.sun.fill"
            case .rain: return "cloud.rain.fill"
            case .snow: return "cloud.snow.fill"
            case .fog: return "cloud.fog.fill"
            case .windy: return "wind"
            case .thunderstorm: return "cloud.bolt.rain.fill"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .clear: return .yellow
            case .cloudy, .partlyCloudy: return .gray
            case .rain, .thunderstorm: return .blue
            case .snow: return .cyan
            case .fog: return .secondary
            case .windy: return .teal
            case .unknown: return .secondary
            }
        }
    }

    // MARK: - Cache

    private static var cache: [String: (weather: WeatherInfo, timestamp: Date)] = [:]
    private static let cacheExpiration: TimeInterval = 15 * 60 // 15 minutes

    // MARK: - Result Type

    enum WeatherResult {
        case success(WeatherInfo)
        case failure(String)
    }

    // MARK: - Public API

    /// Fetch weather for a location at a specific time (with error details)
    static func fetchWeatherWithError(
        for coordinate: CLLocationCoordinate2D,
        at targetTime: Date
    ) async -> WeatherResult {
        // Create cache key from location (rounded) + hour
        let roundedLat = (coordinate.latitude * 100).rounded() / 100
        let roundedLon = (coordinate.longitude * 100).rounded() / 100
        let hourTimestamp = Calendar.current.startOfHour(for: targetTime).timeIntervalSince1970
        let cacheKey = "\(roundedLat),\(roundedLon),\(hourTimestamp)"

        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return .success(cached.weather)
        }

        // Fetch from WeatherKit
        print("WeatherService: Fetching weather for \(coordinate.latitude), \(coordinate.longitude) at \(targetTime)")
        let weatherService = WeatherKit.WeatherService.shared
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let weather = try await weatherService.weather(for: location, including: .hourly)

            // Find the forecast closest to target time
            let forecast = weather.forecast.first { hourWeather in
                hourWeather.date >= targetTime
            } ?? weather.forecast.first

            guard let forecast = forecast else {
                return .failure("No forecast data available")
            }

            let mappedCondition = mapCondition(forecast.condition)
            let info = WeatherInfo(
                temperature: forecast.temperature,
                condition: mappedCondition,
                symbolName: forecast.symbolName,
                conditionDescription: forecast.condition.description,
                suggestion: generateSuggestion(temperature: forecast.temperature, condition: forecast.condition)
            )

            // Cache the result
            cache[cacheKey] = (info, Date())

            return .success(info)
        } catch {
            print("WeatherService: Error fetching weather - \(error.localizedDescription)")
            print("WeatherService: Full error - \(error)")
            return .failure(error.localizedDescription)
        }
    }

    /// Fetch weather for a location at a specific time
    static func fetchWeather(
        for coordinate: CLLocationCoordinate2D,
        at targetTime: Date
    ) async -> WeatherInfo? {
        // Create cache key from location (rounded) + hour
        let roundedLat = (coordinate.latitude * 100).rounded() / 100
        let roundedLon = (coordinate.longitude * 100).rounded() / 100
        let hourTimestamp = Calendar.current.startOfHour(for: targetTime).timeIntervalSince1970
        let cacheKey = "\(roundedLat),\(roundedLon),\(hourTimestamp)"

        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return cached.weather
        }

        // Fetch from WeatherKit
        print("WeatherService: Fetching weather for \(coordinate.latitude), \(coordinate.longitude) at \(targetTime)")
        let weatherService = WeatherKit.WeatherService.shared
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let weather = try await weatherService.weather(for: location, including: .hourly)

            // Find the forecast closest to target time
            let forecast = weather.forecast.first { hourWeather in
                hourWeather.date >= targetTime
            } ?? weather.forecast.first

            guard let forecast = forecast else { return nil }

            let mappedCondition = mapCondition(forecast.condition)
            let info = WeatherInfo(
                temperature: forecast.temperature,
                condition: mappedCondition,
                symbolName: forecast.symbolName,
                conditionDescription: forecast.condition.description,
                suggestion: generateSuggestion(temperature: forecast.temperature, condition: forecast.condition)
            )

            // Cache the result
            cache[cacheKey] = (info, Date())

            return info
        } catch {
            print("WeatherService: Error fetching weather - \(error.localizedDescription)")
            print("WeatherService: Full error - \(error)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func mapCondition(_ condition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .cloudy, .mostlyCloudy:
            return .cloudy
        case .partlyCloudy:
            return .partlyCloudy
        case .rain, .drizzle, .heavyRain:
            return .rain
        case .snow, .flurries, .heavySnow, .sleet, .freezingRain, .freezingDrizzle, .wintryMix, .blizzard:
            return .snow
        case .foggy, .haze, .smoky:
            return .fog
        case .windy, .breezy:
            return .windy
        case .thunderstorms, .tropicalStorm, .hurricane, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return .thunderstorm
        default:
            return .unknown
        }
    }

    private static func generateSuggestion(temperature: Measurement<UnitTemperature>, condition: WeatherKit.WeatherCondition) -> String? {
        let tempF = temperature.converted(to: .fahrenheit).value

        // Condition-based suggestions (higher priority)
        switch condition {
        case .rain, .drizzle, .heavyRain:
            return "Don't forget an umbrella!"
        case .snow, .flurries, .heavySnow, .sleet, .freezingRain, .freezingDrizzle, .wintryMix, .blizzard:
            return "Watch out for slippery roads."
        case .foggy:
            return "Visibility may be reduced."
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "Keep an eye on the weather."
        default:
            break
        }

        // Temperature-based suggestions
        if tempF < 40 {
            return "Bundle up — it's cold out there!"
        } else if tempF < 55 {
            return "Maybe grab a jacket."
        } else if tempF > 90 {
            return "Stay hydrated — it's hot!"
        } else if tempF > 80 {
            return "It's warm out there."
        }

        return nil
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}
