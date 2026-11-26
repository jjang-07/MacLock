// Entry point for scripts/test.sh: runs every Swift Testing test in the binary.
import Testing

@main struct TestMain {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
