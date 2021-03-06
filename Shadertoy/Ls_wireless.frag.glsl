//
//
//                          MMMMMMMMMMMMMMMMMMMMMMMMMMMM
//                        MM.                          .MM
//                       MM.  .MMMMMMMMMMMMMMMMMMMMMM.  .MM
//                      MM.  .MMMMMMMMMMMMMMMMMMMMMMMM.  .MM
//                     MM.  .MMMM        MMMMMMM    MMM.  .MM
//                    MM.  .MMM           MMMMMM     MMM.  .MM
//                   MM.  .MmM              MMMM      MMM.  .MM
//                  MM.  .MMM                 MM       MMM.  .MM
//                 MM.  .MMM                   M        MMM.  .MM
//                MM.  .MMM                              MMM.  .MM
//                 MM.  .MMM                            MMM.  .MM
//                  MM.  .MMM       M                  MMM.  .MM
//                   MM.  .MMM      MM                MMM.  .MM
//                    MM.  .MMM     MMM              MMM.  .MM
//                     MM.  .MMM    MMMM            MMM.  .MM
//                      MM.  .MMMMMMMMMMMMMMMMMMMMMMMM.  .MM
//                       MM.  .MMMMMMMMMMMMMMMMMMMMMM.  .MM
//                        MM.                          .MM
//                          MMMMMMMMMMMMMMMMMMMMMMMMMMMM
//
//
//
//
// Adaptation pour Natron par F. Fernandez
// Code original : Ls_wireless pour Autodesk Flame

// Adapted to Natron by F.Fernandez
// Original code : Ls_wireless for Autodesk Flame


// iChannel0: Source, filter = nearest
// BBox: iChannel0

// Wireless - removes wires, and other straight-ish things
// lewis@lewissaunders.com
// TODO:
//  o width offset for one end of wire
//  o de-stripe by blurring sample points along wire direction
//  o detail restore seems not quite right somehow, looks sharpened
//  o offset start/end, with fade in/out?
//  o soft edge to wire or at least alpha?
//  o overlay colours
//  o respond to image contours/gradients/edges somehow... somehow?
//  o try adaptive median a la IRank - pull in pixels that are most different to the wire colour
//  o sort out the whole resolution/pixels/proxy mode/ResDependent mess!


float myPixelratio = 1.0;

uniform vec2 starttrack = vec2(0.0,0.0); // Start track : (start track)
uniform vec2 startoffset = vec2(0.25,0.25); // Start offset : (start offset)
uniform vec2 endtrack = vec2(0.0,0.0); // End track : (end track)
uniform vec2 endoffset = vec2(0.75,0.75); // End offset : (end offset)

uniform bool overlay = true; // Display curve : (display curve)
uniform vec3 curveColor = vec3(1.0,1.0,0.0); // Curve color : (curve color)
uniform float curve = 0.001; // Curve : (curve), min=-100, max=100
uniform float hook = 0.0; // Hook : (hook), min=-100, max=100
uniform float radius = 0.0; // Radius : (radius), min=0.0, max=1000


uniform float restoresize = 5.0; // Restore size : (restore size), min=0.0, max=1000
uniform float restoremix = 0.5; // Restore mix : (restore mix), min=0.0, max=1.0
uniform float angle = 0.0; // Angle : (angle), min=-360, max=360





// Angles
#define pi 3.14159265358979
float deg2rad(float degrees) {
	return degrees/(180.0/pi);
}

// Return a matrix to rotate about origin
mat2 rotation(float rads) {
	return mat2(cos(rads), sin(rads), -sin(rads), cos(rads));
}

// Return barycentric coordinates for p in triangle v1,v2,v3
vec3 barycentrics(vec2 p, vec2 v1, vec2 v2, vec2 v3) {
	float det = (v2.y-v3.y)*(v1.x-v3.x)+(v3.x-v2.x)*(v1.y-v3.y);
	float b1 = ((v2.y-v3.y)*(p.x-v3.x)+(v3.x-v2.x)*(p.y-v3.y))/det;
	float b2 = ((v3.y-v1.y)*(p.x-v3.x)+(v1.x-v3.x)*(p.y-v3.y))/det;
	float b3 = 1.0 - b1 - b2;
	return vec3(b1, b2, b3);
}

// Return interpolated UVs for p in triangle v1,v2,v3 with vertex UVs u1,u2,u3
vec2 uvinterp(vec2 p, vec2 v1, vec2 v2, vec2 v3, vec2 u1, vec2 u2, vec2 u3) {
	vec3 b = barycentrics(p, v1, v2, v3);
	return b.x*u1 + b.y*u2 + b.z*u3;
}

// Return value at p of implicit quadratic spline function with control points v1,v2,v3
// As per Loop & Blinn 2005, GPU Gems 3
float splineimplicit(vec2 p, vec2 v1, vec2 v2, vec2 v3) {
	vec2 u1 = vec2(0.0, 0.0);
	vec2 u2 = vec2(0.5, 0.0);
	vec2 u3 = vec2(1.0, 1.0);
	vec2 uv = uvinterp(p, v1, v2, v3, u1, u2, u3);
	return uv.x*uv.x - uv.y;
}

// Return signed distance to zero of implicit spline function with control points v1,v2,v3
float splinesdf(vec2 p, vec2 v1, vec2 v2, vec2 v3) {
	float f = splineimplicit(p, v1, v2, v3);
	return f / sqrt(dFdx(f)*dFdx(f) + dFdy(f)*dFdy(f));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 res = vec2(iResolution.x, iResolution.y);
	vec2 coords = fragCoord.xy;
	vec3 frontpix = texture2D(iChannel0, coords / res).rgb;

	// Combine pixel tracks and 0-1 offsets
	vec2 start = starttrack / vec2(myPixelratio, 1.0) + (startoffset * res);
	vec2 end = endtrack / vec2(myPixelratio, 1.0) + (endoffset * res);

	// Figure out bend, our actual b-spline control point
	vec2 slope = normalize(end - start);
	vec2 across = vec2(-slope.y, slope.x);
	vec2 midpoint = (start + end) / 2.0;
	float safecurve = curve;
	if(abs(curve) < 0.01) {
		// Shy away from curve being 0, causes mad freakouts
		safecurve = 0.01;
	}
	float safehook = hook;
	if(abs(curve) < 1.0) {
		// Extreme hooking when curve is small is problematic
		safehook = mix(hook, 0.0, 1.0 - abs(curve));
	}
	vec2 bend = midpoint + 10.0 * safecurve * across + 30.0 * safehook * slope;

	// Grad of the scalar field f is tangent to the wire
	// We're taking the grad and tangent at the current pixel rather than at
	// the closest point on the wire, which isn't totally accurate
	float f = splineimplicit(coords, start, bend, end);
	vec2 tangent = vec2(dFdx(f), dFdy(f));
	vec2 grad = vec2(-tangent.y, tangent.x);
	grad = normalize(grad);
	tangent = rotation(deg2rad(angle)) * tangent;
	tangent = normalize(tangent);
	float tiltedradius = radius / cos(deg2rad(angle));

	// Find the closest point on the wire along our tangent
	// We assume the wire is straight here, without much damage it seems
	vec2 closest = coords - splinesdf(coords, start, bend, end) * (tangent / cos(deg2rad(angle)));
	vec2 closestdirect = coords - splinesdf(coords, start, bend, end) * normalize(vec2(dFdx(f), dFdy(f)));

	vec3 o;
	float m;

	if(abs(splinesdf(coords, start, bend, end)) > radius) {
		// Miles away from the wire, get outta here
		o = frontpix;
		m = 0.0;
	} else {
		// Take samples from either side of the closest point on the wire
		vec2 sample1 = closest + (tangent * tiltedradius);
		vec2 sample2 = closest - (tangent * tiltedradius);
		vec3 color1 = texture2D(iChannel0, sample1 / res).rgb;
		vec3 color2 = texture2D(iChannel0, sample2 / res).rgb;

		// Interpolate between the two samples
		float blend = length(coords - sample1) / length(sample2 - sample1);
		o = mix(color1, color2, blend);

		// Blur along the line, which should give an approximation of the wire we're removing
		// Then we can subtract that from the original to get some detail to mix back
		vec3 blurred = vec3(0.0);
		float energy = 0.0;
		for(float i = -restoresize; i < restoresize; i += 0.333333) {
			vec2 p = coords + i * grad;
			float weight = 1.0 - abs(i/restoresize); // Triangular kernel, bite me
			blurred += weight * texture2D(iChannel0, p / res).rgb;
			energy += weight;
		}
		if(energy < 0.001) {
			// We ain't gon' don' see that
			blurred = o;
		} else {
			blurred /= energy;
		}
		o = mix(o, o + (frontpix - blurred), restoremix);

		// Check if we're off the start or end
		vec3 b = barycentrics(closest, start, bend, end);
		m = 1.0;
		if(b.y < 0.0) {
			m = 0.0;
		}
		o = mix(frontpix, o, m);
	}

	if(length(start - end) < 2.0) {
		// That is an awfully short wire
		o = frontpix;
	}

	if(overlay) {
		if(length(coords - start) < 3.0) {
			float a = smoothstep(0.0, 1.0, 3.0 - length(coords - start));
			o = mix(o, curveColor, a);
		}
		if(length(coords - end) < 3.0) {
			float a = smoothstep(0.0, 1.0, 3.0 - length(coords - end));
			o = mix(o, curveColor, a);
		}
		if((abs(splinesdf(coords, start, bend, end)) < 2.0) && barycentrics(closestdirect, start, bend, end).y > 0.0) {
			float a = smoothstep(0.0, 1.0, 1.0 - abs(splinesdf(coords, start, bend, end)));
			o = mix(o, curveColor, a);
		}
	}

	fragColor = vec4(o, m);
}
