/* Config Sample
 *
 * For more information on how you can configure this file
 * see https://docs.magicmirror.builders/configuration/introduction.html
 * and https://docs.magicmirror.builders/modules/configuration.html
 *
 * You can use environment variables using a `config.js.template` file instead of `config.js`
 * which will be converted to `config.js` while starting. For more information
 * see https://docs.magicmirror.builders/configuration/introduction.html#enviromnent-variables
 */
let config = {
        address: "0.0.0.0",     // Address to listen on, can be:
                                                        // - "localhost", "127.0.0.1", "::1" to listen on loopback interface
                                                        // - another specific IPv4/6 to listen on a specific interface
                                                        // - "0.0.0.0", "::" to listen on any interface
                                                        // Default, when address config is left out or empty, is "localhost"
        port: 8080,
        basePath: "/",  // The URL path where MagicMirror² is hosted. If you are using a Reverse proxy
                                                                        // you must set the sub path here. basePath must end with a /
        ipWhitelist: [],        // Set [] to allow all IP addresses
                                                                        // or add a specific IPv4 of 192.168.1.5 :
        electronOptions: {
          fullscreen: true
        },


                                                                // ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.1.5"],
                                                                        // or IPv4 range of 192.168.3.0 --> 192.168.3.15 use CIDR format :
                                                                        // ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.3.0/28"],

        useHttps: false,                        // Support HTTPS or not, default "false" will use HTTP
        httpsPrivateKey: "",    // HTTPS private key path, only require when useHttps is true
        httpsCertificate: "",   // HTTPS Certificate path, only require when useHttps is true

        language: "en",
        locale: "en-US",   // this variable is provided as a consistent location
                           // it is currently only used by 3rd party modules. no MagicMirror code uses this value
                           // as we have no usage, we  have no constraints on what this field holds
                           // see https://en.wikipedia.org/wiki/Locale_(computer_software) for the possibilities

        logLevel: ["INFO", "LOG", "WARN", "ERROR"], // Add "DEBUG" for even more logging
        timeFormat: 24,
        units: "metric",

        modules: [
                {
                        module: "alert",
                },
                {
                        module: "updatenotification",
                        position: "top_bar"
                },
                {
                        module: "clock",
                        position: "top_left"
                },
                {
                        module: "calendar",
                        header: "SeanandChristine",
                        position: "top_bar",
                        config: {
                                broadcastPastEvents: true, // REQUIRED
                                calendars: [
                                        {
                                                symbol: "calendar-check",
                                                url: "https://calendar.google.com/calendar/ical/sean.chinery%40gmail.com/public/basic.ics",
                                                name: "sean",
                                                color: "#90e24a"
                                        },
                                        {
                                                symbol: "calendar-check",
                                                url: "https://calendar.google.com/calendar/u/0/embed?src=cmarcinkiewicz@gmail.com&ctz=America/New_York",
                                                name: "christine",
                                                color: "#e24a90"
                                        },
                                        {
                                                symbol: "calendar-check",
                                                url: "https://www.warrentboe.org/calendar/ical/WarrenCalendar.asp?cal=1&woodland=true",
                                                name: "school",
                                                color: "#e6e600"
                                        }
                                           ]
                                }
                },
                    {
                        module: "weather",
                        position: "top_right",
                        classes: "myclass1 myclass2",
                        config: {
                                weatherProvider: "openweathermap",
                                type: "current",
                                location: "New Jersey",
                                locationID: "5106129", //ID from http://bulk.openweathermap.org/sample/city.list.json.gz; unzip the gz file and find your city
                                apiKey: "1ccb887686523d4a92fd94bd950702e5",
                        }
                    },
                        {
                          module: "MMM-CalendarExt3",
                          position: "bottom_bar",
                          title: "",
                          config: {
                            mode: "month",
                            instanceId: "familyCalendar",

                            locale: "en-US",
                            firstDayOfWeek: 0, // Sunday (use 1 for Monday)

                            maxEventLines: 5,

                            calendarSet: [
                              "sean",
                              "christine",
                              "school"
                            ],

                            eventTransformer: (event) => {
                              if (event.calendarName === "sean") {
                                event.title = "S: " + event.title
                              }
                              if (event.calendarName === "christine") {
                                event.title = "C: " + event.title
                              }
                              if (event.calendarName === "school") {
                                event.title = "W: " + event.title
                              }
                              return event
                            }
                          }
                        },

  ],

};

/*************** DO NOT EDIT THE LINE BELOW ***************/
if (typeof module !== "undefined") { module.exports = config; }
