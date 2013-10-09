### Oozby Scope ###

Oozby is an extended version of the Ruby programming language, so uses all the same scope conventions as Ruby itself. In addition to this oozby provides several methods which can be used to change the state of the language, manipulating the coordinate space, changing the default operation of method calls, and adjusting resolution settings. All of these methods can be called with a block, applying their adjustments only to oozby elements created inside that block. Some methods can also be called without a block to change the settings of the oozby environment more generally. This second form is considered bad style and not [idiomatic](idiomatic.html) except for a specific circumstance: Setting the resolution and defaults for an entire file, as the first statements in the file before constructing shapes.


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `resolution(fragments_per_turn:30, minimum:2, fragments:0)`

All shapes in oozby are represented by straight lines, so curved shapes like circles, spheres, cylinders, rotate_extrude, rounded cubes and squares are discretized in to polygons or polyhedrons during rendering. `resolution()` configures how many faces are used to represent curving surfaces. The default values are shown above and any or all of them can be changed either for a `do ... end` block, or for the entire environment by calling resolution() without a block at the top of your oozby document.

When OpenSCAD was first developed these defaults seemed appropriate, but as home 3D printers have gotten better, these default values can look pretty rough. While the defaults are great as a way to design shapes initially because calculations run quickly, before doing your final render to save a printable or cutable STL file, you may wish to increase the resolution by adding something like this to the top of your document:

```
resolution(fragments_per_turn: 100, minimum: 0.5)
```

Each of the arguments are as follows:

* `fragments_per_turn:` maximum number of straight lines used to draw a circle
* `minimum:` minimum length in millimeters of each fragment. Smaller shapes use fewer fragments
* `fragments:` when set to non-zero, override previous two values and always use this many fragments, regardless of object size

Note also that `fragments_per_turn:` describes one full rotation of a circle. Objects like rounded squares will use one quarter as many lines to represent each corner. You can also specify `degrees_per_fragment:` instead of `fragments_per_turn:` if you prefer.


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `translate([x, y, z])`
#### > `translate([x, y])`
#### > `translate(x: Numeric, y: Numeric, z: Numeric)`

Translations move the current scope to a new position within 2D or 3D space. Coordinates can by specified as a 2 or 3 item array of Numeric values, or as named arguments.

Translations are always relative to your current coordinates, not the global coordinates, so they will add to the current values, not replace them.

```
# two spheres side by side
translate(x: -15) > sphere(10)
translate(x: +15) > sphere(10)
```


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `scale(Numeric)`
#### > `scale([x, y, z])`
#### > `scale([x, y])`
#### > `scale(x: Numeric, y: Numeric, z: Numeric)`

Scale multiplies the size of it's children. In the first form a value of 1.0 would cause no change, with 0.5 halving the sizes and 2 doubling them. Think of it a bit like zooming. By specifying an array or named arguments you can scale each axis differently, allowing you to stretch and distort primitives to create ovals, stretched spheres, or oval cylinders.

```
# sphere stretched to be twice as long over the x axis
scale(x: 2) > sphere(10)
```


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `rotate(Numeric)`
#### > `rotate([x, y, z])`
#### > `rotate([x, y, z], v: [x, y, z])`
#### > `rotate(x: Numeric, y: Numeric, z: Numeric)`

Rotate around the current position by a number of degrees. It doesn't so much rotate it's children as much as it rotates the scope in which it's children are created. Rotations affect children translate calls, scales, and everything else. Rotation is applied in the order x, y, z, regardless of argument order. The optional argument `v:` allows you to specify an axis around which to apply the rotation. Check out the [OpenSCAD documentation](http://en.wikibooks.org/wiki/OpenSCAD_User_Manual/The_OpenSCAD_Language#rotate) for more details on rotate.


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `defaults(center: false)` 

`defaults()` reconfigures default settings for oozby primitives like square, cube, and cylinder. Currently this is only `center:`. Call defaults with a block and all oozby primitives created inside that block will use the new default instead of the standard value (typically `center: false`), which can make your code more tidy and readable where you may have been manually specifying `center: true` every time you made a primitive shape while creating complex shapes with boolean operations.

```
# these two lines are functionally identical:
defaults(center: true) { cube(1) }
cube(1, center: true)
```


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#### > `preprocessor(false)`

call `preprocessor(false)` with a block to disable the oozby preprocessor for the method calls used within the block. The preprocessor handles mapping friendlier argument names across, validating call argument types, adding support for rounded shapes, etc. This might be useful if you need to work around a bug in oozby. If that is the case, please report your issue on the [oozby bugtracker](https://github.com/Bluebie/oozby/issues) so it can be fixed for a future version.
