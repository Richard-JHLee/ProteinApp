import Foundation

// MARK: - Language Detection Utility

struct LanguageHelper {
    /// 현재 시스템 언어가 한국어인지 확인
    static var isKorean: Bool {
        let currentLocale = Locale.current
        
        // 다양한 한국어 로케일 형식 지원
        return currentLocale.identifier.hasPrefix("ko") || 
               currentLocale.languageCode == "ko" ||
               currentLocale.identifier.contains("ko_KR") ||
               currentLocale.identifier.contains("ko-KR") ||
               currentLocale.identifier.contains("ko_KR@") ||
               currentLocale.identifier.contains("ko-KR@")
    }
    
    /// 현재 시스템 언어 코드 반환
    static var currentLanguageCode: String {
        return Locale.current.languageCode ?? "en"
    }
    
    /// 현재 시스템 로케일 식별자 반환
    static var currentLocaleIdentifier: String {
        return Locale.current.identifier
    }
    
    /// 다국어 텍스트를 위한 헬퍼 함수
    /// - Parameters:
    ///   - korean: 한국어 텍스트
    ///   - english: 영어 텍스트
    /// - Returns: 현재 언어에 맞는 텍스트
    static func localizedText(korean: String, english: String) -> String {
        return isKorean ? korean : english
    }
}

// MARK: - Localized String Extensions

extension String {
    /// 한국어/영어 텍스트를 현재 언어에 맞게 반환
    /// - Parameter english: 영어 텍스트
    /// - Returns: 한국어일 경우 self, 그 외에는 english
    func localized(english: String) -> String {
        return LanguageHelper.isKorean ? self : english
    }
}
