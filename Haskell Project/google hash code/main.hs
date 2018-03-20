import System.Environment 
import Data.List.Split
import Data.List
import Data.Function
import qualified Data.Map as Map
data Ride = Ride{
                 rideIndex::Int,
                 startPos::Position,
                 finishPos::Position,
                 startTime::Int,
                 finishTime::Int,
                 carIndex::Int,
                 score::Float
                 } deriving (Show)
data Car = Car{
               index::Int,
               curPos::Position,
               current_steps::Int,
               rides::[Ride]
               } deriving (Show)

data Position = Position {
                          row::Float,
                          col::Float
                         } deriving (Show)

-- distance stuff

getDistance:: Position -> Position -> Float
getDistance posA posB = abs  (row posA - row posB) + abs (col posA - col posB)

----------- SEEMINGLY RELUCTENT NOW -----------
{-class Distance a where
    getDistance:: a -> Ride -> Int

instance Distance Car where
    getDistance car ride = abs  (curRow car - startRow ride) + abs (curCol car - startCol ride)

instance Distance Ride where
    getDistance rideA _ = abs  (startRow rideA - finishRow rideA) + abs (startCol rideA - finishCol rideA)


-}
----------- END OF SEEMINGLY RELUCTENT NOW -----------

-- parsing rides stuff
computeScore::Ride->Int->Float
computeScore ride bonus = fromIntegral bonus + getDistance (startPos ride) (finishPos ride)

updateScores::[Ride]->Int->Int->[Ride]
updateScores [] _ _ = []
updateScores (x:xs) bonusPoints i = x {rideIndex=i,
                                      score = computeScore x bonusPoints
                                      } : updateScores xs bonusPoints (i+1)


parseRides::[String]->[Ride]
parseRides [] = []
parseRides (x:xs)  = if x == "" then [] else  Ride{rideIndex = 0,
                                                  startPos =  Position { row = sr,
                                                                         col = sc
                                                                       },
                                                  finishPos = Position { row = fr,
                                                                         col = fc 
                                                                       },
                                                  startTime = st,
                                                  finishTime = ft,
                                                  carIndex = -1,
                                                  score = 0} : parseRides xs where
    [sr',sc',fr',fc',st',ft']  = splitOn " " x 
    sr = read sr'::Float
    sc = read sc'::Float
    fr = read fr'::Float
    fc = read fc'::Float
    st = read st'::Int
    ft = read ft'::Int

--get avarage funcrtions

genericAverage :: (Real a, Fractional b) => [a] -> b
genericAverage xs = realToFrac (sum xs) / genericLength xs

getGlobalAvarage::[Ride]->Position
getGlobalAvarage [] = Position {
                                row =0,
                                col = 0
                               }
getGlobalAvarage a = Position{
                              row = genericAverage [row (startPos x) |x<-a],
                              col = genericAverage [col (startPos x) |x<-a]
                             }



-- todo - finish this
evaluate_cars::[Ride]->[Car]
evaluate_cars [] = []



main = do
    -- get the file name from args
    fileName <- getArgs 

-- read the text file and split to all the lines
    text <- readFile $ head fileName
    let textLines = splitOn "\n" text

    -- split the first liine to its parameters
    let [r,c,f,n,b,t] = splitOn " " (head textLines)

    -- parse the parameters of the first line (from string to int)
    let rows  = read r::Int
    let columns  = read c::Int
    let vehicles  = read f::Int
    let rides  = read n::Int
    let bonusPoints  = read b::Int
    let steps  = read t::Int

    -- parse the rest of the lines to Rides
    print $ tail textLines
    let rides = parseRides (tail textLines)
    let rides2 = updateScores rides bonusPoints 0 
    print $ rides2
    print bonusPoints




-- the function recieves specific car information, list of all potential rides, and choose which one is the most fitting ride 

map_of_steps_per_ride::Car->[Ride]->Map.Map Int Int

map_of_steps_per_ride car [] = Map.empty
map_of_steps_per_ride car (x:xs) = Map.insert (rideIndex x) (count_number_of_steps car x)  (map_of_steps_per_ride car xs)

score_ride::Car->Ride->Int->Position->Float

score_ride car ride bonus global_average = drive_distance - car_pickup_distance - fromIntegral (maximum_waiting_time + bonus_score) - distance_from_global_average where
    drive_distance = (getDistance (startPos ride) (finishPos ride))
    car_pickup_distance = (getDistance (curPos car) (startPos ride))
    maximum_waiting_time = fromIntegral (max 0 ((startTime ride) - current_steps car +  round car_pickup_distance))
    bonus_score = if car_pickup_distance + fromIntegral (current_steps car) <= fromIntegral (startTime ride) then bonus else 0
    distance_from_global_average = (getDistance (finishPos ride) (global_average))



comparing_by_score_ride::Ride->Ride->Car->Int->Position->Ordering

comparing_by_score_ride rideA rideB car bonus global_average
    | score_ride car rideA bonus global_average < score_ride car rideB bonus global_average = GT
    | score_ride car rideA bonus global_average > score_ride car rideB bonus global_average = LT

{- *** here we can use liftM2 with Monad implimantations and other cool stuff. like implement a functino that holds all the filter conditions, and then apply them on the filter
       see the post https://stackoverflow.com/questions/841851/how-do-you-combine-filter-conditions *** -} 


{- the function recieves a specific car, a list of all the rides, the maximum number of steps
   for each car, bonus points and outputs the best fitting ride for the car, or None if there is no such ride available. -}


pick_ride::Car->[Ride]->Int->Int->Car



pick_ride car rides steps bonus =  where
    global_average = getGlobalAvarage rides
    filterd_rides_list = filter (\x -> carIndex x == -1 &&
                                 steps_map Map.! rideIndex x < (steps - current_steps car) &&
                                 (current_steps car + steps_map Map.! rideIndex x) <= finishTime x
                                ) rides
    steps_map = map_of_steps_per_ride car rides
-}
-- each car is limited to 't' number of steps, so we need to count for each car the number of steps it has left for every ride.
count_number_of_steps:: Car->Ride->Int
count_number_of_steps car ride = (current_steps car ) +
                                 round (getDistance  (curPos  car)  (startPos  ride))+
                                 round (getDistance  (startPos  ride) (finishPos ride))+
                                 (max 0 (startTime ride - finishTime ride ))


