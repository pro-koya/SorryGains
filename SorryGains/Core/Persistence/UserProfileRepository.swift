import Foundation
import SwiftData

protocol UserProfileRepository {
    func fetch() throws -> UserProfile
    func save(_ profile: UserProfile) throws
}

@ModelActor
actor SwiftDataUserProfileRepository: @preconcurrency UserProfileRepository {

    func fetch() throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(descriptor)
        if let existing = profiles.first {
            return existing
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try modelContext.save()
        return newProfile
    }

    func save(_ profile: UserProfile) throws {
        modelContext.insert(profile)
        try modelContext.save()
    }
}
