Oozby (Oozebane + Ruby) is inspired by the realisation that OpenSCAD does not truly support variables, and so it is more like a markup language than a programming language. Oozby aims to give users a similar interface to OpenSCAD, but with the more sensible and clear syntax of Ruby, and with a bunch of extra features patched in. Check out the examples folder to see some great demos of the features Oozby offers.

Here are some highlights:

 * For built in functions which take an '`r`' parameter like `sphere`, `circle`, `cylinder`, you can specify any of these instead:
 * + `r`, `radius`
 * + `r1`, `radius\_1`, `radius1`
 * + `r2`, `radius\_2`, `radius2`
 * + `d`, `dia`, `diameter`: _anything specified as diameter will be automatically halved, taking a lot of `/ 2.0` statements out of your code__
 * + and of course `d1`, `dia1`, `dia\_1`, `diameter1`, `diameter\_1`, `d2`, `dia2`, `dia\_2`, `diameter2`, `diameter\_2`
 * Built in functions which take 'h' like `cylinder`, `linear\_extrude` can take `height` instead if you like
 * Cubes and Squares have 'radius' option, which if > 0.0 causes the corners to be rounded very nicely. 
 * Full support for variables, can use all of ruby's core and standard libraries, use rubygems to pull in data - read images, access web services, read databases, automatically download things from thingiverse, whatever
 * For cylinders you can specify a Range for the radius option instead of specifying r1 and r2 separately if you like
 * All the round things have a 'facets' option which translates to $fn
 * No semicolons (of course!) - specify one function as the parent of the next by using a block or use the > operator (see examples)
 * Lambda, classes, methods, oh my!
 * Built in functions like translate, rotate, scale, which take a 2d or 3d vector [x,y,z] can instead have options passed like this:
 * + `translate(x: 5, y: 6)` - unspecified items default to 0
 * + `scale(y: 2)` - unspecified items default to 1
 * Specify defaults: You can create a context within a block where everything defaults to `center: true`! How many times have you had to write `center = true` again and again when constructing something with lots of symmetry in OpenSCAD?
 * Establish a scope within a block with specific resolution

This tool is considered very experimental at the moment and could break in horrible ways. There is a good chance the API will change and break stuff until the gem hits 1.0, but hey, get on board and lets figure out how to make OpenSCAD less horrible. Maybe if we come up with really great ideas in Oozby that will give the OpenSCAD devs a clear direction forward for new syntaxes and features in the future - kind of the same idea as rubinius and pypy! A place to quickly prototype kooky ideas.

Oozby is not a language translator and doesn't try to be. It is a markup builder like Markaby or XML Builder, so you should expect it's output to sometimes be not very readable and unnecessarily verbose. Your variables and maths are all rendered by Oozby, and as a result Oozby cannot and probably never will be able to generate dynamic modules which can be used from OpenSCAD files. Of course, you can use Oozby libraries from inside other Oozby scripts! And it probably wouldn't be too difficult to implement the OpenSCAD language in Oozby itself, so it could automatically convert OpenSCAD in to Oozby and in that way allow OpenSCAD files to call on Oozby libraries.

Another note: Oozby uses regular ruby maths, and that means if you're not working entirely in whole millimetres you may encounter a little bit of floating point rounding. You should try to make surfaces intersect, not just come up against each other's edges exactly. Anything that wouldn't look right rendered by the quick opengl preview mode of OpenSCAD might not work properly with full CGAL renders. Also note that in ruby `5 / 2 = 2`. If you want `2.5`, make one of the operands a Float, so `5 / 2.0 = 2.5` or `5.0 / 2 = 2.5` or `5.0 / 2.0 = 2.5`. We could use refinements perhaps to patch the oozby environment so `5 / 2 = 2.5` but that would be weird for existing Ruby users. Not sure what to do here.
