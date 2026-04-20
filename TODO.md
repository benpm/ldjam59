
# Game Design
You are the last hope to reconnect power to the radio transmitters. You must connect a power cable to each station while avoiding the corrupted evil power cables that chase you throughout the map. The radio towers, operating only on limited backup power, send out distress beacons every second which light up the world around you.

## Notes
- In the game files, "cable" refers to chains, the terms are interchangeable

## TODO
<!-- AGENT:
    When asked, start doing tasks from top to bottom.
    During work, stop if there is a major issue, consistent build issues that have nothing to do with the task, etc. etc.

    - Before completing task:
      1. Check that task has sufficient information. If not, skip it for now
      2. git pull

    - After completing task:
      1. compact current context, update markdown files including anything in notes/, README.md and AGENTS.md. if a markdown note is bigger than 500 lines, split it up in a semantically meaningful way.
      2. run "godot --quit --debug --headless project.godot" and fix any errors
      3. mark task as done, copy it to the Completed section below
      4. commit and push, resolve merge conflicts if they are simple
 -->


---

- [x] The player_cable is no longer able to be picked up. Fix the bug, also, its now bound to E, so make a small text box appear saying to press E
- [x] Make the enemy cables target somewhere near the player, some distance away in a changing direction via cos() and sin(), angle slowly changing. If player gets close enough, very quickly snap to the player to attack
- [x] While holding the cable, if the player approaches the a tower, indicate that the player can press E to plug the cable into the tower. This should make the tower light up yellow and cease to make waves via the shader
- [x] Make the camera follow the player, but only in the horizontal direction. Make it orbit a central point many units away, making a wide circle. The player's motion follows the camera, so that pressing and holding the right arrow key will actually make the player travel back to their original point, if held down long enough. The camera's distance from the central point should remain constant. The central point's position should be visualized, as well as the circular path the camera will track along.

- [x] Make the jump action into a dodge move, where the player leaps in the direction they were last moving as well as jumping upwards
- [x] Add some friction to the linear motion of the DynamicChain points
- [x] In the material used for the chains, use a gradient for the alpha value for the fragments on the first 10 or so segments - blending them into the background so their start is not visible
- [x] Show a visual indicator when player is near the end of the player_cable, indicating that it can be interacted with. Also, limit the distance that it can be interacted with.
- [x] Add a parameter to the enemy script that sets the length of its chain. Draw a circle in the editor to indicate the range of this chain (radius of circle = length of chain).