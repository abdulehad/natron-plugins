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
// Code original : crok_heathaze Matchbox pour Autodesk Flame

// Adapted to Natron by F.Fernandez
// Original code : crok_heathaze Matchbox for Autodesk Flame


// setting inputs names and filtering options
// iChannel0: pass1_result, filter = linear,wrap=clamp
// iChannel1: displace_map, filter = linear,wrap=clamp
// BBox: iChannel0

// low frequency blur in x 

uniform float blur_low = 20.0; // Smoothness : (blur the incomming distortion matte), min=0.0, max=1000.0
uniform bool external_matte = false; // External matte : (use an external matte instead of the internal matte for the displacement)

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   vec2 coords = fragCoord.xy / vec2( iResolution.x, iResolution.y );
   float softness = blur_low;
   int f0int = int(softness);
   vec4 accu = vec4(0);
   float energy = 0.0;
   vec4 finalColor = vec4(0.0);

if ( external_matte )
  {
   for( int x = -f0int; x <= f0int; x++)
   {
      vec2 currentCoord = vec2(coords.x+float(x)/iResolution.x, coords.y);
      vec4 aSample = texture2D(iChannel1, currentCoord).rgba;
      float anEnergy = 1.0 - ( abs(float(x)) / softness);
      energy += anEnergy;
      accu+= aSample * anEnergy;
   }

   finalColor = 
      energy > 0.0 ? (accu / energy) : 
                     texture2D(iChannel1, coords).rgba;
  }   
  
  else
  {
      for( int x = -f0int; x <= f0int; x++)
      {
         vec2 currentCoord = vec2(coords.x+float(x)/iResolution.x, coords.y);
         vec4 aSample = texture2D(iChannel0, currentCoord).rgba;
         float anEnergy = 1.0 - ( abs(float(x)) / softness);
         energy += anEnergy;
         accu+= aSample * anEnergy;
      }

      finalColor = 
         energy > 0.0 ? (accu / energy) : 
                        texture2D(iChannel0, coords).rgba;
  }



		
			  		  
                     
   fragColor = vec4( finalColor );
}
