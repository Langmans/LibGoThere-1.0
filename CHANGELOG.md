# Changelog

## Unreleased

- Navigate, NavigateNearest, Cancel, TravelTime, Providers and PinLink.
- Providers: Shortest Path Forever (route and travel times), Move Fast (route
  and travel times), TomTom, the game's own waypoint, a map pin link in chat;
  RegisterProvider for others; ForgetTravelTimes.
- TravelTimeNearest: the spot of several reached first; a provider may weigh
  them all at once (Move Fast does, in one plan).
- HasTravelTimes: whether a provider with travel times can be asked.
- Move Fast leaves out a spot on a map it has no data for, instead of failing
  the whole plan.
- Providers for Waypoint UI (Forever, retail) and Carbonite (every client),
  both before TomTom.
- Where the client can open no map pin link (Classic Era), the last resort
  writes the zone and coordinates as text.
