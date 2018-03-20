#include "Wire.h"
#include "NewPing.h"   // this library should be downloaded

#define En_pin 2  //digital pin 2 for Echo
#define D4_pin 4  //digital pin 4 for Trig

#define ECHO_PIN 2 // Arduino pin tied to echo pin on the ultrasonic sensor.
#define TRIGGER_PIN 4 // Arduino pin tied to trigger pin on the ultrasonic sensor.
#define MAX_DISTANCE 500 // Maximum distance we want to ping for (in centimeters). Maximum sensor distance is rated at 400-500cm.
                          //over this distance, result is 0cm
                          
NewPing sonar(TRIGGER_PIN, ECHO_PIN, MAX_DISTANCE); // NewPing setup of pins and maximum distance.

void setup()
{
  Serial.begin(9600); 
}

void loop()
{
  unsigned int uS = sonar.ping(); // Send ping, get ping time in microseconds (uS).
  /* The following is for monitor visualisation */

  Serial.print(uS / US_ROUNDTRIP_CM); // Convert ping time to distance in cm and print result (0 = outside set distance range)

  /* The following is for processing visualisation */
  Serial.write(uS / US_ROUNDTRIP_CM); // Convert ping time to distance in cm and print result (0 = outside set distance range)
  
  delay(500);
}
