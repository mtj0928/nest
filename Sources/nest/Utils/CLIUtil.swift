enum CLIUtil {
    static func getUserChoice(from options: [String]) -> Int? {
        for (index, option) in options.enumerated() {
            print("\(index + 1)) \(option)")
        }

        print("Enter the number > ", terminator: "")

        while let input = readLine() {
            if let choice = Int(input), choice >= 1 && choice <= options.count {
                return choice - 1
            }
            print("Invalid input, please enter the number.")
            print("Enter the number > ", terminator: "")
        }
        return nil
    }
}
