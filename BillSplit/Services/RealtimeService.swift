import Foundation
import Supabase

class RealtimeService {
    static let shared = RealtimeService()

    private var channels: [String: RealtimeChannelV2] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]

    func subscribeBills(groupId: Int, onChange: @escaping () -> Void) {
        let channelId = "bills-\(groupId)"
        guard channels[channelId] == nil else { return }

        let task = Task {
            let channel = await supabase.channel(channelId)
            await MainActor.run { channels[channelId] = channel }

            let changes = await channel.postgresChange(AnyAction.self, schema: "public", table: "bills")
            await channel.subscribe()

            for await _ in changes {
                await MainActor.run { onChange() }
            }
        }
        tasks[channelId] = task
    }

    func subscribeSettlements(groupId: Int, onChange: @escaping () -> Void) {
        let channelId = "settlements-\(groupId)"
        guard channels[channelId] == nil else { return }

        let task = Task {
            let channel = await supabase.channel(channelId)
            await MainActor.run { channels[channelId] = channel }

            let changes = await channel.postgresChange(AnyAction.self, schema: "public", table: "settlements")
            await channel.subscribe()

            for await _ in changes {
                await MainActor.run { onChange() }
            }
        }
        tasks[channelId] = task
    }

    func unsubscribe(groupId: Int) {
        let billsId = "bills-\(groupId)"
        let settlementsId = "settlements-\(groupId)"

        tasks[billsId]?.cancel()
        tasks[settlementsId]?.cancel()

        Task {
            await channels[billsId]?.unsubscribe()
            await channels[settlementsId]?.unsubscribe()
        }

        channels.removeValue(forKey: billsId)
        channels.removeValue(forKey: settlementsId)
        tasks.removeValue(forKey: billsId)
        tasks.removeValue(forKey: settlementsId)
    }
}
