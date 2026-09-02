// Fall 2026 course schedule — Notre Dame.
//
// Only START times are recorded, because that is all the registrar line
// gives ("MWF 10am"). Don't invent end times; the widget shows starts.
//
// days: JS weekday numbers, 0 = Sunday. "TR" is Tue+Thu, "Th" is Thu only.

export const COURSES = [
  { code: "CSE 20321", name: "Computer Organization",  days: [2, 4],    start: "09:00", accent: "cyan"    },
  { code: "CSE 20312", name: "Data Structures",        days: [1, 3, 5], start: "10:00", accent: "blue"    },
  { code: "MATH 20550", name: "Calculus III",          days: [1, 3, 5], start: "11:00", accent: "green"   },
  { code: "CSE 20110", name: "Discrete Mathematics",   days: [2, 4],    start: "12:30", accent: "magenta" },
  { code: "CDT 30750", name: "Generative AI in the Wild", days: [2, 4], start: "14:00", accent: "orange"  },
  { code: "CSE 21312", name: "Data Structures Lab",    days: [2],       start: "15:00", accent: "blue"    },
  { code: "MATH 22550", name: "Calculus III Tutorial", days: [4],       start: "15:00", accent: "green"   },
];

// Fall 2026 first day of class. Also the epoch Hammerspoon's Hyper+C uses
// to work out which "Week N.canvas" to open — keep the two in step.
export const SEMESTER_START = new Date(2026, 7, 25); // Aug 25 2026, local

export function minutesOf(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

export function coursesOn(date) {
  const day = date.getDay();
  return COURSES.filter((c) => c.days.includes(day)).sort(
    (a, b) => minutesOf(a.start) - minutesOf(b.start)
  );
}

export function semesterWeek(date) {
  const week = Math.floor((date - SEMESTER_START) / (7 * 86400000)) + 1;
  return week < 1 ? 1 : week;
}

export function label12h(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  const suffix = h < 12 ? "am" : "pm";
  const hour = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${hour}${suffix}` : `${hour}:${String(m).padStart(2, "0")}${suffix}`;
}
