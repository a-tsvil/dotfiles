import QtQuick
import QtTest
import "../../settings/sddm/charcoal-city"

TestCase {
    name: "CityMotion"

    LeafDrift {
        id: scene
        width: 1920
        height: 1080
        visible: false
    }

    function init() {
        scene.frame = 0
        for (let i = 0; i < 12; i++) {
            const leaf = findChild(scene, "leaf" + i)
            leaf.lifetime = 768
            leaf.spawnOffset = 0
            leaf.spawnY = 0.87
            leaf.swirlPhase = 0
            leaf.swirlTurns = 3
        }
    }

    function test_wallpaper_loads_with_crisp_pixels() {
        const wallpaper = findChild(scene, "wallpaper")
        tryCompare(wallpaper, "status", Image.Ready)
        compare(wallpaper.smooth, false)
        compare(wallpaper.mipmap, false)
        compare(wallpaper.fillMode, Image.PreserveAspectCrop)
    }

    function test_sideways_pixel_steps() {
        const leaf = findChild(scene, "leaf0")
        scene.frame = 32
        const x = leaf.x
        const y = leaf.y
        scene.frame = 36
        verify(leaf.x < x, "Leaves must blow from right to left")
        verify(Math.abs(leaf.x - x) > Math.abs(leaf.y - y))
        compare(leaf.x % scene.pixel, 0)
        compare(leaf.y % scene.pixel, 0)
        compare(leaf.rotation % 90, 0)
    }

    function test_leaf_drift_has_no_sudden_turns_or_large_steps() {
        const leaf = findChild(scene, "leaf0")
        scene.frame = 40
        const x = leaf.x, y = leaf.y, angle = leaf.rotation
        scene.frame = 41
        verify(Math.abs(leaf.x - x) <= 2 * scene.pixel)
        verify(Math.abs(leaf.y - y) <= scene.pixel)
        compare(leaf.rotation, angle)
    }

    function test_leaves_stay_low_opaque_and_use_fine_pixels() {
        compare(scene.pixel, 2)
        for (const frame of [0, 384, 767]) {
            scene.frame = frame
            for (let i = 0; i < 12; i++) {
                const leaf = findChild(scene, "leaf" + i)
                compare(leaf.opacity, 1)
                verify(leaf.y >= scene.height * 0.77)
                verify(leaf.y < scene.height * 0.97)
            }
        }
    }

    function test_leaves_have_three_frames_and_varied_forms_and_hues() {
        const leaf = findChild(scene, "leaf0")
        const frames = []
        for (const frame of [0, 3, 6]) {
            scene.frame = frame
            frames.push(JSON.stringify(leaf.rows))
        }
        compare(new Set(frames).size, 3)
        const other = findChild(scene, "leaf1")
        verify(JSON.stringify(leaf.rows) !== JSON.stringify(other.rows))
        verify(leaf.leafColor.toString() !== other.leafColor.toString())
    }

    function test_leaf_spawn_changes_only_when_it_wraps() {
        const leaf = findChild(scene, "leaf0")
        scene.frame = 10
        const spawnY = leaf.spawnY
        const turns = leaf.swirlTurns
        scene.frame = 11
        compare(leaf.spawnY, spawnY)
        compare(leaf.swirlTurns, turns)
        scene.frame = 768
        compare(leaf.cycle, 1)
        verify(leaf.spawnY >= 0.84 && leaf.spawnY < 0.90)
        verify(Math.abs(leaf.swirlTurns) >= 2 && Math.abs(leaf.swirlTurns) < 4)
    }

    function test_leftward_wind_has_varied_speeds_and_up_flat_down_paths() {
        const leaf = findChild(scene, "leaf0")
        const slow = findChild(scene, "leaf1")
        leaf.lifetime = 576
        slow.lifetime = 1152
        scene.frame = 100
        const fastX = leaf.x, slowX = slow.x
        scene.frame = 108
        verify(leaf.x < fastX && slow.x < slowX)
        verify(fastX - leaf.x > slowX - slow.x)
        compare(findChild(scene, "leaf0").verticalTrend, -1)
        compare(findChild(scene, "leaf1").verticalTrend, 0)
        compare(findChild(scene, "leaf2").verticalTrend, 1)
    }

    function test_gusts_keep_leaves_moving_left_without_teleporting() {
        const leaf = findChild(scene, "leaf0")
        scene.frame = 0
        let x = leaf.x
        for (let frame = 1; frame < 768; frame++) {
            scene.frame = frame
            verify(leaf.x <= x)
            verify(x - leaf.x <= 4 * scene.pixel)
            x = leaf.x
        }
    }

    function test_tower_lights_fade_fully_off_and_reach_full_brightness() {
        const light = findChild(scene, "towerLight0")
        scene.frame = 0
        const initial = light.brightness
        compare(initial, 0)
        scene.frame = 12
        compare(light.brightness, 1)
        scene.frame = 36
        compare(light.brightness, 0)
        for (let index = 0; index < 5; index++) {
            const beacon = findChild(scene, "towerLight" + index)
            let darkFrames = 0, peak = 0
            for (let frame = 0; frame < 48; frame++) {
                scene.frame = frame
                if (beacon.brightness === 0) darkFrames++
                peak = Math.max(peak, beacon.brightness)
            }
            verify(darkFrames >= 23)
            verify(peak > 0.99)
        }
    }

    function test_other_towers_have_pulsing_red_beacons() {
        for (const index of [3, 4]) {
            const light = findChild(scene, "towerLight" + index)
            verify(light !== null)
            compare(light.color.toString(), "#ff6753")
            scene.frame = 0
            const initial = light.brightness
            scene.frame = 12
            verify(Math.abs(light.brightness - initial) > 0.1)
        }
    }
}
