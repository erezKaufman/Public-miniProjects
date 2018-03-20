/*
 * This arduino file is to be used with the 
 * sound sensor equipped with microphone
 */
 
const int soundPin = A0; //sound sensor attach to A0
const int threshold = 200; // detarmin the threshhold that above it we consider 'noise'
void setup()
{
  Serial.begin(9600); //initialize serial
}
void loop()
{
  int value = analogRead(soundPin);//read the value of A0
  Serial.write(value); // write to process
//  if(value > threshold) //if the value is greater than threshold
//  {
//    
//  }
  delay(250);
}
