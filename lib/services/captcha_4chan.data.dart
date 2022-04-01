part of 'captcha_4chan.dart';

const captchaLetters = ["0", "2", "4", "8", "A", "D", "G", "H", "J", "K", "M", "N", "P", "R", "S", "T", "V", "W", "X", "Y"];

final Map<String, List<_LetterImage>> captchaLetterImages = {
	"0": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -1.5,
			data: "eJz7/x8CGJDAfzRAbTlkMXR5asvhs58ecujitJRDpmktxwMEuNxDCzl6xR8+Nq3k0N32Hw1QUw4A+V+fMA=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -1.5,
			data: "eJy9k9sOgCAMQ/v/P12NCWYrrcRE7BscGN0F8hchglMRWIZbFA7RgqExOaP+DENhbMzE0DiZzZ5NnZBY9+nfSnk+sLe15eiNY9jBopdP8r+WifX7vS6u52PLMc13zcrazsDTfCgrcWfPqxlgQKx/i0YRsHZvrw6G0rVn"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -1.5,
			data: "eJzFlFEOgDAIQ3v/S2MyNUqhQIxG/pS30gFq9mMAmFGoSNwpCe4puJC1ILn14FI5lQjMKCuos37SFOU20X5IcVFJuSt0FA9PUCsj3Y/mJuPIzyiEJRIUOrlwoOBmVxhRVTvs2q84lkwmHd77FIOSKj4c96Ki2Bxov/hs3tBYgRxoH+yznRs3MYDln7aUiWBH7eSE+iw2jlCweg=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -1.5,
			data: "eJy91EsOwCAIBNC5/6XpSsIgA9aFrJr4lI+mZu8CwAh6A492UZgNIK5FYBXYNt6ClS43XJaVz/sLOIuYzRnACOLouMhi+HJ2qacRNEHdSeNUHjOCoZMWmL8HBv4tRl09slvApgaiyBMQryG/hxro2XFCkZU2j0BMB/KfJTdn1AIq7UV8EXY29A=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -1.5,
			data: "eJzN1FkKgDAMBNDc/9IRxUKamUnqApovbZ/NQtH9N2HWiz0WSKUsxvFaE3lg2ErKULEPsuLJefuj9lnRarPiPUmlJgMliQEzhT02JeEH15WiARUHhmydgsenqmr03GrGMZvXRzsWW0WOdc8KkjuaWuXFOyqtyqFA4VqRCnJa0XN/d2MZtcF7jgLyVsT5X/Sz2ACZabB6"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -1.5,
			data: "eJz7/x8KGFDAf3QwUNIoophKaCWNw60M6GBQSGPI0EkahTFopHlAALfzaSpNn/gmRRpVLQaH9tKYbv2PDmghDQDOVQYI"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -1.5,
			data: "eJzNk1EOgDAIQ7n/pTFGF6GlmCVzsZ88XEsT3f8ma9CpjglsjxxXjPSODTDuTWFyoY99BA9YWN0DlSRj1Z4ugTFVU9sa7q3CvJOSK2xYVH3hJ7iLtrM6o/Zys/AKlJowV17jNJnAcVIemHyX4BhAn0nPRCz++gvL+sCgZiPjXh3VZEvf"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -1.5,
			data: "eJzV0tEOgCAIBVD+/6dpM5sicLkrfYg342jAUP1hiAgvpdBiJNI9KzbAb134Jmw2leE7J6Ri2c5LIpVRYpt0BSBpJ8BI4WXLoY7yfXgvQXTCS98AkuvWRji4hS1brPKyGJVOm/xBmiPaELt7J6TDSMKOlk+FnL6PQy51kTaiBlw9G+TIzjfT8WUVJviZQRbVa5Fm5K1ZeT4u0up7vQ=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -1.5,
			data: "eJzN1FkOgCAMBFDuf+lqAoYuUzpporFfQp8sFRH5a4w7GFOxsaPKpywarWZDZbCJb79uZguVCu4WDdsxbrrM6IUXZjBm6NK7NVffkDU4Vpoxx7BVObnND4ox9eYKM/u7RsLJhEbwfdA13mUm/6s4s/ueR8b4ypmx3TRtE6dhTFrbtTNgNMNp6woj9iR9GRfspeFJ"
		),
	],
	"2": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 1,
			data: "eJz7////fwYs4D8UUFsOXR02tdSU+48F0FNu1K5Ru4iRoxcAAH+PLe8="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 1,
			data: "eJyt0ksKwDAIBFDvf2nbQkFHZ/IBs5I+MWrjPnjMTAs3+88XUgjnEAafwEoui2uRiGmvXuc5MFIxcvuczeg+q2AfsFF6RysoTJC23V1rm+uD7Pyij8ldrQfrdvgueB3xLJqZZUoVEVIfBTC1tSuhGl8J3ZgE3/0bAe95AO3lROY="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 1,
			data: "eJy91UsOgDAIBFDuf+kaMdECw3Q0sSzhpXxcOIYcpqkzNMWkV2wO+gyFUBUZ873Muf7JlCAjpsTiNl0DppaMH7oqxrYqLyiq/U5XPSp826n01LFiE9WRG8VHFheLI9u9LOuF75NH1jZ/f5+s4MhIdfGTolDbEki592b5cSHSWvgPRLlULg/2g2/J"
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 1,
			data: "eJy90kEOwCAIBED//2lammglwK4kRI4wItiKtMR4g4LMfOmxIj28BwXW7LnEmAQwcVO8NwByBvgdwKC3vQE0y0D83bRmQPCn+cMU2NH2BzzoXpjdFykwtfLmldkMmNchEEYjyA1bw5m2RhcvS8RvUjARBGoeCsPeTA=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 1,
			data: "eJzN0kEOgDAIRNG5/6U11YUt/QM1GiO7micM1W37qCTVQrnSVec5JU1BR5myYp47C0yH3a3KN4VF7is7bnwXL6VT0BbmTW1dpOMcRTrBj8tVYUxYzrRi1tTTSIvq/eD/+SxFpPK37nI4Mz4nIsUJUSkUjJtFDE6CmvMitWCF11qKUTlBV+VUJVrt6FNvyQ=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 1,
			data: "eJz7/x8IGLCC/zAwQNKYarFroIX0f+xgcErj8AvNpQfKXvzSo6ExCKxFlR4AAADLWLlj"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 1,
			data: "eJzF1EkOgCAMBdDe/9KoMSrtH8AhsSvgQVtItLUfIiIsKo4jtrGya4u0jstqZjhAJ5jsBpMuzwm/oOdriFyf0DDJzTOnfHBQlcvMbZKlWp5pa8gmt+7K8wddvWHf16Ou5WuVrwTO9Ezy5X21GOHooo25bkTbJ5iW/W5UJXF3ZbweY0L1VpylrbEAhcEMLQ=="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 1,
			data: "eJzF01sKQCEIBND2v+kuFPTS0bEH1888iROU86tKvCzFS1vXZprKm+ZpJKVeWyYXp+ZscXRB1i5IK6VyNygZai6LpEN/k6V3X86lkVVmKHt3mEb9AjIFlG6KQN41Reqv4KRAD83IFnAgUKrDeOlsCPLqEtdzGcVH/2Bbx3Z+usqJtrceuSubpmTRH5cSb9c="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 1,
			data: "eJzF1UkOgDAIBdDe/9I41MR8xq+SyhJeGOpCkdUx9mBM7GZh3JF0gGCMYpgNHWZSFjZ/YMJ7U3MpxhSI2YlZfJE58z0m+LCzrFZxjW3BGFXFTX2TbcoYW6auqebYqlSP1nENGnGvscaPfpM6hr1q9W3kf2O53aq/CLrKHGwD6Hm3gQ=="
		),
	],
	"4": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 2,
			data: "eJz7/x8VMEDBfyyA2nIMSIDWcgxogJZyyHxayw2U3fQCuOIXXXxUjjg5AI70Dg8="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 2,
			data: "eJzN1NEKgCAQRNH7/z+9ERW564wgRTZPypFVVzDixQBetHFmuXFnQB8YOIMHZu5+zYVhrZk31q2t52mrKHO9MZYryr32cd8XTKbM3jWfs7RLm3jHYxwp1EKrTUGMvoH/ZgPwYCUG"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 2,
			data: "eJzl0ksOgCAQA9De/9KYoJFhppaycEV3lpfhE1s7NQA8BSXvJbwRUzwFoXrnqJq47ql0ZKF4wvtMLVek9VR51Rl4ql7nVxWgakZPN8hS/F95JldcMsV2/4w50GO7qnmqf1pqefrT1YAL9UhDbeYC+AFb3Q=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 2,
			data: "eJzd1EsKwCAMBNC5/6WnILWhdvKTrsxGjA+NipKHBoAUuAYGtMErmmAkErBGA4jBOhiNpRTwU00wl4vAWvLfwIzbn7loUrHp+m0K8wH6YBO0NUsdMAW8n1IEwiLPBo8JAAtfWTkuoizCaA=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 2,
			data: "eJzd1MEOgDAIA9D+/0/jzWylFE5mszfJkwlLjPgoAHqBRuHNUQq9wpaJOUWxESoTr9xWl3qnUlvZyimu0jN4Oj3IXqyWkj5prgTi4+o26Y1yGh2jzP7WulfDu7BK3/yqWNQnXKYciclv9395AIBeW90="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 2,
			data: "eJz7/x8dMMAAhsyASjMgA/pJM2CAQSGNIkI/6UHjEDzSAwD+YwA8UqPS9JAGAKLih5U="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 2,
			data: "eJzV0ssKwCAMRNH7/z+drtrm4QQsiHWWOShh1GxDgBYVc+dnjMs0s41BMyXzbKq1Z/KF6dhPPGPlQN0+3DbmpljJcWllxL7Enou56ygtn9uWXN/uZYuhXngUj83S3zg3Fwr501c="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 2,
			data: "eJzt0ksKwDAIBFDvf2kL0haljg75dJXZxTwII1E9mYiI8NJSkiALfN9ukFJLm7IySyC8/LSoJYoroXEOZTtvtrdK6vs/CJmt4yfpcTNzN+CpRCMJdosk0rMSV1ygeToklZd2piXV6MgF0uFePpyUA7kAEWpT8w=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 2,
			data: "eJzt1DkKACAMBMD9/6djEYvI5jBCOrcR4ygeoMjPEQA3BomDMRHDmSGjpdpQmsYdbxltTdE3WXHIaK82dMwhYxxPZFYsDp7RePfQPRpmPoou5GGtnpEbI/sLKEy1529ylprtStPJAhyGg7U="
		),
	],
	"8": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -3.5,
			data: "eJz7////fwYs4D8UUFsOXR02taNyxMvhC2tayNHbf8NdDl9Y00IOAPtPfpA="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -3.5,
			data: "eJztlEEKwDAIBP3/py2FgnVcUw8e68lkxKxKdF80M+uJZvbY7UoQXINg6SoxxCqfScKXWp31zBgz1moWmXeMegdM9g7nrIUC0YMPa6Ny6n9+i/Mb/pkqmrW8nz7XWedX+yCAn1YNF8nMLrJClYc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -3.5,
			data: "eJzt1EEOwCAIRFHuf2mb2o3AB8fEZVnCU4E0HUMO09QbmurkrNga7TUtRJWkz1cy5wjiG5paChvldr1TpqlZkRRuhybVlO/zkoowNs1D8IwR7tQnyxuk0/BQOijswP7vK/R5SUVYKidTDqfF8ZNEVS+S/qKhXiiaDtUiy7qTgjqMB9EdfK4="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -3.5,
			data: "eJztlDsOwDAIQ33/S9PPEEGwASkd663WK02MVbNPhFstoJjXxpJ82asFIuM9ymxGZsjUFlhuAdgMQAs89jweBYhNkTDOAfAVQfSB3CJCJQAfj/iSGrz3gQBpPQywvw8VANEH9lgBKR6QoSGecDaSTvop5TmWFQ9DAAt9kGqBsS5Lzw8c"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -3.5,
			data: "eJzNklEKgDAMQ3v/S09kH2L60opCMX8bz6bJXGtIEdETUVNxaZ9L5KRgYhhZIvtmArfD6Zaqk0KQVxTb2VpmqFywUhhXKS5F/QpKL2F7iQQZOXyh/hOwhnOTwb2QtvyNYjtbywz11/8LKIp0v3CpuRTdsic2pWhC0kBLSH8V1RKPdAD1f3yu"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -3.5,
			data: "eJz7/x8IGLCC/zAwQNKYarFrGJWmmzR2tagaBkiaMo+NStNAGrtaVA20kgYAX//oJg=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -3.5,
			data: "eJzlktsKwDAIQ/3/n3ZssNVLklLY6MPyVD3WNqL7BpmZhAzbrfPM2CihLOCSzbhdgEFvtoDBL58AG5zjPgAwgg+wC5y6vIiN45ipP2+GYO1EorI+snMd/rQtxnHKrOHqJQbAZ/NPXqIW0LbAERIJdGEFlQ6xwEze"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -3.5,
			data: "eJzt1cEOgDAIA1D+/6dnMi/baEujIfEgx/EGisscoyvClzN8qfWdjC2qapVmMuszxTlaxZi165Brrpb7t3Nk+HLmbBm+HPIg5TKfkAnnN2YjYENSvSqtCtlFYE+wXc2HyjUJOpHJd8j/zJ8rvtz1G8muYrwf3cVMwuJUwtpUwieU/0rVF3NTPogLIzVA+A=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -3.5,
			data: "eJzl1UsOgCAMBNDe/9L1GwnDDIwG3dhl+/iUNJr5dcQajtHuKESJzg5VOAZYneWuyRBGd59lSr5rzopjwjFbwTD4FKo5xySfnzcNOmyItcd6RzcwO1OLxyvJEWJ6m7a5yekz5pifzCE6ZYLO2CNzJdmrIGNGvS35HEOZmvYq8i+hjiFuaO7EAjps1lQ="
		),
	],
	"A": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 5.5,
			data: "eJz7/x8BGIDgPw5AbTkGJEBrOWQxdHlqy+GzfzjJ0RsMJr8PZTkALfO+UA=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 5.5,
			data: "eJzN01EKwCAMA9Dc/9LdBptoTKxjDM2fPCmpYMSmATCgzKTjzjtDCXcCJTE0Rnd4N2GorO0rZvAcb/oN3D5jm3qHGWPq+nemoOqUxN6yo22fz7uvMvkHnrM0mh0iP5qi8HKZgTMH5LXVRw=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 5.5,
			data: "eJzV09EOgCAIhWHe/6VtY6uJHOGfV8Zd8gVCa4x/hBlTBqB1zLNEvaHzTHnGQpS9tPOHkNJKFGAq7TaCoCa3u62ofajWplsVRuhU+/GmDFJLMBVkqdRghdxWQG+TRmw6ti221auU/v+y+g5a5YdIpbhVFUvSslUuH0h21FY="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 5.5,
			data: "eJzV0ksOgDAIBFDuf2lMjVQonzFsWmdl2kfQicynhSAY6YL7BoAnHUBrICB9pwFHwA12gayTowiERx1gtyTdfAMEga4uA76mCkT1ZKgE5tXMHBhCu+EXwBpgURvBfM4Brz96AHx+AV6SAkElGOYCpt1W1A=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 5.5,
			data: "eJzV1NsKgDAMA9D8/09XBXHaZmnnUFieRM7sBZnZQkGB7KmYASUpWiYV8FCMgkUocwpRsQNe8eL+U9czGZd26xWfqat6mwktTSlejqzjveImLlgqRXD+xoPJjxRK5zN8tNUVlLoXbm+lYsW94i3+rgQq38mZOLIBmATUVg=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 5.5,
			data: "eJz7/x8ZMADBf9xggKQZUAD9pFFEMZUMkDQOrzCgg5EqPZBgEAfLCJMGAHHjPd8="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 5.5,
			data: "eJzd01EOgDAIA9De/9LoD1FoYZgsxthP39yAZWY/CYBeJ1ysgWc/4wq1AMqakTivi0zb0M/mld1Y7+UfiqMSiz6mrAe4ZjFCnuETJuWWFWsD31WXxcqGuxq68ndN7QtcvckBh0MS5xpM5hXWKt9A5NLOHKqcg6c="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 5.5,
			data: "eJzd0eEKwCAIRlHf/6UdS6jEyjvWYNv3rzyImer/I8LlGS4TWgCVNTPyhLSi+GQDzqwdfXUqh3241LXU7tfDAKsHjOa5JcMAe6TfFZHCZalhGcKl15lsmkjTq0a4yQUJp+P74Xvnf/Ri6Y77ZLsi0u6xjPmK7HEqq0ay6ANxx6KW"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 5.5,
			data: "eJzV1FsKACEIBVD3v2mHcCLJ1yUZmO5fdSQUivn+EGJGWkYOa/PmU0MmiNFKFurEN7a6ZWSlN33jbx6b7bqO0c0VhhBDevSx2YIYzRLjdBOzqLiuxEzFkLaRCSJz/odh81KODc8/LDdebjRLZWa6ygz2AICRFyI="
		),
	],
	"D": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 0,
			data: "eJxjYMAE/6EAixTV5NDV0UOO1n7CJodNflSOfDl0cVrK4eLTQo5abiYkBwC/OE7A"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 0,
			data: "eJzt01EKwCAMA9Dc/9LRDXRrTUQQ97V8VZ5gaZH8JLBQY0EaehgdOV5ugwRx08uGGZ+0/LbB9YR+W7RMag90lusjlnpTNU69Hc6xDzm8ydez+2CMhcdGaCblMgM1BSDVZbc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt0tsKgDAMA9D+/08rzMGsSdYMhPlg3tYe3TXiMBItnqpkpHhKSVQMUgUy15V7Vreqm8Ma2yqdwVNwu+8oc+etwxVCoZT71SdUGzlKpfc9Ffk9aVVEL7n4bkwzkVd79ahB9sPlmf4GYaXGJWzLCUhSQOo="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 0,
			data: "eJzt0UESgCAMA8D8/9M4wKhtCQ16wIs5hoUpAJQ8qJEgQzCRgBqMkcAb21Hhq53gJqEY7/Lx3JCg1gREw8CrT/7BYwD7RRPA0tckSCJBM6vluaZOvsZeeztv+nORTDdHlAI32o4cpdzfPQ=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt01EKwCAMA9De/9IdOtBSY1JhsH0sf47XYotz/0zMtGgpEKYsph+pgA2xGMqY6ApW8prRvK6YDStXSs2cVGWBtTX/6k2FDXsTLhU8Z4WrDtTycVVoJHLP0P10mqcVvhX5P92V8pwC2eyQqZ2YiolbKdFyAYpMQOo="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 0,
			data: "eJxjYMAK/kMBdlk6S2MqprM0bscOCmnsakalB1AaQ2ZwSGOI0Ecau0NpKg0A5YmecA=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 0,
			data: "eJzt1MEOgDAIA1D+/6cxehkU2uBhiwd7m6+JbEvm/rWYoDvKCNuKQ8VqJD5szEJlGNXkM8yZVvQmM9cOPd+fz3DRMaePgstiM+OwmctGCLd/2skwdX/4UV9enUOUBW5oMUHHxxFzAWbQ9Sc="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 0,
			data: "eJzt1EsKwCAQA9Dc/9KWaguiyUyEumhpVuo8xQ8IoHjBioSn0cWXsR6l1kxyreSsx5K2c+GNssdsFBTz+WwPSpbNkpxUXspZk5LgJ2Rgf/lVWbuuDHIRX9amLfOEf28+e12mm2vCucLp6Yi+30olW41pRzbtyv05AN/G4Eo="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 0,
			data: "eJzt1UEOgCAQA8D+/9MaidG41LaYGDnYG8tAYA8AYHFBZizDkcTcO9QkhjhqCrtWuaq1ec2pugppAe3INwaJ2Sao6dhzw9VvpjRt5A3PPp0YmcRAnVQuGjDuIvQFKUb0X/wTaovOGdOYN29kBcZ2d7M="
		),
	],
	"G": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -1.5,
			data: "eJz7/x8CGNDAfyRAbTlsamklR0+7BloOPbxpLYfuhuEghy28aS2HK5xpIQcAUHPeMA=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -1.5,
			data: "eJzd0zEOgDAMQ1Hf/9JhCZKh+QYkWPD62iYptOrFSGKZTR2ExRCChDqpubZAs13Viva4DzLRiXZPQjiazkHYbYI2ILdljc85GvQTxvuJ3fgWcOUnKMn+z6E+Hd6G70+2t4YglE/3bTZwLPUn"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -1.5,
			data: "eJzt1MEOgCAMA9D+/09joolxXVt2MPHijvCQbSBrfRgAZgpJ4qksvKZQwu7V4gGq4iX6MzwYVKu4AkraKNuqXxmlsTzCmWrSqiL7GNClrBEsbSdYauXu+az8NxXDUTvS/5aUTC7sMFPxiFVy25pAj49tJC3hmCkFpWrSqiKjuuVWnfIAT4cAOQ=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -1.5,
			data: "eJzl09EOgCAIBdD7/z9NyxVJ3Atrbr3Ik+nRAZrZfwGgBbWBR7koTAKTGaNnNhuyrQWxpHktJMfPqyrcCRBGGt8CvFvOr04kiRCiimh4mSAhcoePNbg+14Foj3qYX4FPrYN8RWpPCRD+ct4dcECN5WiB0acnjQQ3KsFpDqb4fqw="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -1.5,
			data: "eJzt1EsOwCAIBNC5/6XpxhZBYDAmrsrWp4OfKHKpAHCBWkGrQRKFXcKjipYbu/oUMdIOOz7FWR221FGgce7SAuXFqiJhVSYmVZFXEeNVNkFVFT2GyB46p/UrowyNlV2wMMnDkBE0qbRbGq+K/l++m1UsuRWRzu9+sR7VWgA5"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -1.5,
			data: "eJz7/x8KGDDAf2QwUNLYNdBceoCsHVrSmNE2aKQxXTxCpbFEG32lsbqV9tIAkMRPzQ=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -1.5,
			data: "eJzl1EESgCAMA8D8/9P1IlpKkxZnHA/mugIBVLMPAkAiY4woS7hrybxqyYv1Xgp+NrhTq2K1MG0lGKK0OmaE7HBExyvdnNtgqjOvz83nQ5j209v+Mzdvld5cJKvZf0RpWdHiZPXSw89gaZRZ8RN9JwcZjKiC"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -1.5,
			data: "eJzt1N0KgCAMBeC9/0sbSJTz/LgIL4LOnduXMpFa+2Aioi5joSNJp89u5JhjWaYhcotjtckOOfaI7GsclkudX+6W6gMm+fZKonYyc1aNOXZ21EpSLaWxVpprQXlXdkjATmZL6nU51CuyPZTsz/Reru8EH7GUiI3UmkmulUTtZOZLeemS7PoAPT7eWg=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -1.5,
			data: "eJzt0ksOgCAMBNDe/9L4i9LPDG1MFy6cFSkPkkHH+GpkT8VkTGayfcqi0e5aqjlg8GyXcS9hd20fcm3yMr+pGESDAVdCI+G7QaNdmIgN7eUY6y4wvHHFDPvrJo27jHfMaPXGzFmXkS7zDBNzzpGJDhvMggEOGseY0W5lbpeZg21hhUL2"
		),
	],
	"H": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 3.5,
			data: "eJxjYICA/0iAAQ2Myg1+OXqDweT3UTni5QD7T36Q"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 3.5,
			data: "eJzt0zEKACAMQ9Hc/9K1DlKo+aPQwWzyapCCERghZBDA9N6E1u6X3d1q+WZJCKqdewNoYwhUje8Zuc+JZv/aOVtr3WHy0BwFyzaAzAJCspWH"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 3.5,
			data: "eJzt0UEKwCAMRNG5/6VbSCHYqplPVyk0O8enwSgdoBTFlJNCrJUaklJlalXsIKVfvVZPuFU3WaqETl1yewM6TRqx17Fpdf3HD6phUaoMrIoQqam6qmJIa2lVyBO/zHiy"
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 3.5,
			data: "eJzt0cEKACAIA9D9/08XQmWRbleDPKU8iRrQeMFKAoYKA+9TMGcU2FgBfEBNDBBElCEKsEd07Ikldbd8gfyGCllUBuucg9FScNcTwEkKJqLATAfk8gck"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 3.5,
			data: "eJzt1EEOwCAIRFHuf2mMcVPqlM/Gpo3O0jxEQqJ7IcaihwUos0+oqWBS8tqgHpubzFHrlTZh8UkKZCgQqoYFtuYZfrCh3VT2SV1OU6Wa35V+4usqQc5iKBI9DQ9peLI="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 3.5,
			data: "eJxjYICC/yiAAR2MSo9KDw0wiENtVJpu0gCYYegm"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 3.5,
			data: "eJzt1EEKACEMQ9Hc/9Idd1aNH3FAZJhsXzFFwQiKUJFVQjZnnWQRD8ckdi2LrDT38zseVECVvSk93UJgkkpovzsu9fMc+9yUdNzvEDZH2Kv9llqeWskDoDRM3g=="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 3.5,
			data: "eJzt0UEKwCAMRNG5/6UtKGhESL5QIdLOzvERUSUVFu1IMS0TLn2aWdoulL1Hsu4dkPplCrlgT846kkMT2bQ3CA+hZ/Jb89e85d8/Jqfle3JURLYeyzW3SItD2TWSVT97ey8K"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 3.5,
			data: "eJzt0dEKABAMBdD7/z9NxCaxu+IBuW+bszQABBb4DGWQvGC0Y5naZSYdbDL4Zqfp3cy0zDDiiMlsNswn+RWelTyvc9p/vWW0WDalZmaUG40qy1THTGIR8bLJYQ=="
		),
	],
	"J": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 7,
			data: "eJz7/x8BGNDAfxrLIcuji4/KjcphUzfc5JD52MKE2nIA2+VNzw=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 7,
			data: "eJzt0EEOABAQQ9He/9KI1ZR+C7HUlcmTEW0NI4QRhGwSmASEYPTOih++9u3brQmtnN38XrV1Rx2S0dtoaf+cpbRjydZD6sq2YYcBvLLdUDgdPT5kxg=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 7,
			data: "eJzt1DEOwCAMQ1Hf/9J0gC7wk7gVHZDqEb2EgAStnRHJUzKg7niqkJIp5UmPPVXZ1UxdPFVO/6s3ivWqqC+rWcZKByp+zUnpTkVTcOlYR7X8IKxABgq2DhQeJYeV6tJRn+UC1RyviQ=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 7,
			data: "eJzt0FEOwCAIA1Duf+kuGjOHlNVsfmyJ/UOfEAS+FpOgRII7Yz1aTKJHXeYBJAD/OrXEBhQQN4LQiwCPfgjOOgft6D0IM+kbk8AFLhJ4U4sALobdJUsnRoGlOQCWNBIn"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 7,
			data: "eJzt1DEOwDAIA0D//9NUmVqMwemOt6ADogyJuAi8OPFiVPjGC428uBrzT4VXeaJWvHfVqlX5+9GKC1WpNlaobW9VdBUlZ4OLo5rviXzqFDrTqOCMi5g6oZ6nUVZc5QGh7q+J"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 7,
			data: "eJz7/x8ZMKCD/4NGGkUJptSo9Kj0gEljqh2VxhDBlKKlNAAju9BM"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 7,
			data: "eJzt0EsKwDAIBNC5/6VNNwU/44SQbgrOLjwjqpkKpErGE2UtAy3D5cSifs+bqTXb8PC/GYr9I3OqDVxbka+F+0EuOBd7Bkov0NQtybHeezWWWlCzeHLGClUWY1suCw=="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 7,
			data: "eJzt1FEKwCAMA9De/9IdOgaWJS5iZeCWP/VZqx+67x8zXZboUtEWM2LT9EDdFUVbo8s6lqV0o1++K+kWJPEBTN55V9rHZJh7kg7fP0vinliBa2Vagv+KScyphH1QSV6iE12eWpXrcwCiD6+X"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 7,
			data: "eJzt0kEOwCAIRFHuf+lp2phUBGRM6MLYv8S3UAOwf8KYO8YkTLooxLsq46M1A8Yg+nri6b+pN661xjLXDO4Q806mpg2rTDdKLilVRgcdY0YX7J9i/rF2iXlYbr7oApu63lo="
		),
	],
	"K": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -2,
			data: "eJxjYICA/0iAAQ3QUg6ZT2s5etpNShgMRTl6h+dA2T8QYYwuT005AEUTvlA="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -2,
			data: "eJzN00sOwCAIBNC5/6Wp3cEwozamadmZJ/JJjLABCyMsGMPantXqBiLkk+6jFs7G/eaDMjenNfX+rHa1cMb7WVtfPig+sDa7yt2zNCv6fjl3YvXeWW/v7FHM43KF7fzRP5mi8HKbgREXPULVRw=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -2,
			data: "eJzN1FEKwCAMA9De/9IbVBguS9NAP6Y/w/rAWHERlzEih6c6GRY7Sm0VqZ5qq3KFq5wFHTwtVevDN4OceG9cfWJgDSdezrl634/Ruv/VNtOqenkThbBUVVexIhULJ3bwVPsesThRuGmp4AhaqZPTcKtYK/139hQLd4jiTeLyBv0i1FY="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -2,
			data: "eJzN1O0KgCAQRNF9/5fekBAZurNLBpK/dDr5sWERWbcYrQUV+jFYYwtmVoIRA5A4GFC7n5npF3hELUgNtNvuaBvM01SAanoArL4HeAl2gBoGVKg0U5h3voPyXrzcNwBdhYGU1IOQIYFHDMD/4FqQ+PGPAzg+mAtF32LI"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -2,
			data: "eJzN1FEKwCAMA9Dc/9Idsh+NaepEmP0ZlLdaO2fEQqAWLWpRKOCbqtezLUXSN4QZFSfmllSPrPR2OWOUrA1OWuX7RN3nrPpBJSoodpRcblS68dtUNlVTcEfR/JCdQl1QKj7R02vvo0ue2NM/H09RVrpgrsoLz/1/Zt1LlUHL13UlWjy+NNRW"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -2,
			data: "eJxjYICC/yiAAR0MCmkUETpKYygeFNKYXhiVZhgEMYYhMriksQcmHaUxlNBCGgBYoCL6"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -2,
			data: "eJzN0zkOwCAMBMD9/6cJZew9xFEkdGgsY1YwRlqIGhlzJfOMJT45VzBIUbY0Fcr+iHttqzbsTsrciytTL83mlhT1BrfGO8wBfMScmm6xwe8UoF4LD3HDbRjYYUMSxFxTsrxldcvQQbL4RKvMof6Stap/1djaXA8PRXyu"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -2,
			data: "eJzN1VkKgDAMBNC5/6UjFLTBZLJIwOav49M2dQMgtUJHoqahqi5jerLUWSqfvCTXsQG5hmBFW/WlbcA5SxHx4yDai7Lpy1DpXW1M7l0YlfTO/i31OJX8WzEgDY5ksPNNyeb35M4rUppSZ6mE+3Z8k2YBkTQ7kEr0pTMNbevOI5n/3OqSL+04aZ/AWF9OKJWj"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -2,
			data: "eJzd0+EOgCAIBOB7/5em1czqPIG01Ra/Ar8laAGwKJAzIUONP5ij4pm9Gpl1YdhsGUTIQaThJqVpixnTvIue/faQGCEyl9uaM/JWXjWnzDUlf8oQ6xl9hnljGSManzPBv0zFYUPb9Qw17hncMCXXRiz0hwuUZ0x/cl8aeSqKLWP5FiM="
		),
	],
	"M": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 0,
			data: "eJxjYICA/0iAAQ3QQg4mj02cVnL0BDB34AoXWsjRM/5G5YamHAASH07A"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 0,
			data: "eJzt08sKwCAMRNH5/59OHxDEdi5IaMBFZxePihgSgRHCGQQw9ZsMKasX3Gvz3TK5VsnybMkI1vLhe0Y/aX/J4E9d/37bwuysZW3tcXeYNJqjYMlJ9jkAEVxltw=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt0VEKwCAMA9Dc/9KORRjF1SZ+KWP50vaBxQLNCBhPKQmLbVUjDFdg6kJBKhZzxcPYypSIp7I5luO95M29rAqu1hJavanV3bdUtaZffV6FS6meglQsWuqVU1XxSbmUivIC1tg48g=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 0,
			data: "eJzt0sEKwCAMA9D8/087enBB2qSMXdwwp7Y8RLTA8EGkBQ5tBVbDBigJWwtiUoA8zkCnBW/Snt3e7wEQcAGV4BNbUP/hAX8Bd63B4JpIkPMJQCLBRBaEuQDn9c9N"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt1EsKACEMA9Dc/9IdxBG01CRuhlmYpX3UL0YYgRYtWggF/EJha4bKbZFSbzerte3Sm1NXKQSDnMea11sdU6NE1FSyFDvatyQuk7yvq65Kin1S0yhV1eRZ1Uv8XBEUWnSlRMsDhDM48g=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 0,
			data: "eJxjYICC/yiAAR0MpDRcDXYZ2ksPTgAPLDyBSlPpwZlaRqVHpRkYAACMsF4="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 0,
			data: "eJzt1M0KwCAMA+C8/0t3HkaZWRpWBA+y3PQTf7Aa4QKrljHirGbsZEhFNt90M63S4XlczTnFAhv7HjOLOZ3lR4F0OXsXuLwXXS0/n8X80Bs8LULMewiZLayVvyXBpY1cAqkJIg=="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 0,
			data: "eJzt0dEKgCAQRNH5/58u2KBWt9xbKRQ4TzoeUFlJC4vuSDEtFy7b9EMyYF/UsrS+QtLqDtJW8fRc5uHy4lnPwi8d8ZVqgiNkw/rxIGkGy2T4U075QhbbfvKoiNx6LGP+Ij1O5a6RNL0ComvdTQ=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 0,
			data: "eJzt0sEOABAMA9D+/08TEiZs63CS6EXKO0g2AIkFMUMZel40s5MGWEo6M+Xq2NRzflmNm4i5TvQjTG0a0+4bXQ1jYsbYrG++0YyUa5OGBXWMlheNKM80x0xhGVrQfK4="
		),
	],
	"N": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 1,
			data: "eJxjYICA/0iAAQ3QQg5Znl5yMHl6yP0DAlzqaSE3UOFMr/QyKkcdOQDQ7E6w"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 1,
			data: "eJzt00sOABAMBNC5/6WLhJCaIX47s+OljWhqJgMJMRKE4b1Bmquv1veGS7pR1tYuW3ZmmJuijWy/YWxn/0XmMJrRtwtGd62cqbneRvLQGJmWdpP7BPbxZbc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 1,
			data: "eJzt0sEOgCAMA9D+/0/PZAeCMNtqNHJgt5V3GAMgjEKWp5SExX5VI+xa4NJ1gVQZWmoqT5GRa6hUfbF25Cm6pIcqu9sjj0o6b+tvPuFHisAIx21lqNPvJKoFUmVoqalWVWRJtZQq5QEqKDjy"
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 1,
			data: "eJzl00EKACAIBMD9/6cLITBRV6pL0d6UOUga0HggKQFDVwFrtABCoiUF0qkAFkEyWoB2gHZzMC3/DMA9jwfZ7FTEC74WJKZV4nNgTjUGo6TA5wkw/SGWEojpyOTPTQ=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 1,
			data: "eJzt1NEKgCAMheHz/i+9sMhK1/5djCjoXOrnNlA0S0QsWliAkl6hpgOTcste1G1zuVk3UI0FSYnVYSlphaYmlSPvN8qq7nK6Ct5E7uX86qMq+qROq6Hymo/KH/FxFSBjsSkSLQvXdDjy"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 1,
			data: "eJxjYICC/yiAAR0MpDSqmgGQhisZVNL/QAC3JppKD+LIGsiUOio9WKQBotewSg=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 1,
			data: "eJzt1MEKACEIBND5/5+2LgvZjmNYxB52rk9UEjJTgVTJ6FEWM24yFL/aDMymLDJcXcy+RY2fEs5Y41jLSZpuLpzykeemB03u/fMX2Orshkw872A0V5gr/ZY8h9bTAN9uCSI="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 1,
			data: "eJzt01EKwCAMA9Dc/9IddLBW3drILDhY/ozvq1YAwgUzEpyGCy9jupEcsC962VpfUVLrAnkTXnqbSdOMfJqM3fIym/Yrqcf1Mgg/b/4dK5ajWsZY+vxyByntd1glrWLk2dNyzFekx6m8NCVVHyra3E4="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 1,
			data: "eJzt08EKwCAMA9D8/093OETdZk3QXgrLLe07iQVgLNAMZWjJaN6uN8BTvTNTRkHmE8VAMc3tmmG+NHUTZe4WY+ZRns79VDmMy8y4+s2usefBnJjamZkloxnveh3FFHYBPHV7rw=="
		),
	],
	"P": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 4,
			data: "eJxjYMAO/gMBDimqyP1HAtjUjcqRJodNLS3l/mMBo3KDXw4AIjTuIA=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 4,
			data: "eJzt1EsOABAMBNC5/6XrE0m1OlhYkOiqPNHWgsjBAMAlNrQoaQjqMaiZLWPurObzS1aVJ+3eYMLMvfuOgVm/NuZ603xs2s/Sl95+A7FBgcz+7TmLiH801QjkSPLbBSY="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 4,
			data: "eJzl0EsKADEIA9Dc/9IzIMNQm6hZFupSX/oReIxClKcmiVSeqiQrBaUimfuV5J6C8g5PLYNBfSNPwVMxsZTczmFqh6VKslUQC29keYKVFhdRUP6OgnJbOrZLQ5VPuFctrlW/HFVIS91eL/7YGCE="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 4,
			data: "eJzt0lEOwCAIA9De/9IsLptBKZRPs6yf+JAEBawORiSoEFwkoAYxEqzG16jZCtGQWyWY1WpRPQAJRrm/nhMA+BNlJgUvKgH8epY+0RRn8x+0PQ8D1vkP90EN6MDvgkly8JgS/LELNTeWlA=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 4,
			data: "eJzt0DsKwCAQBNC5/6U3iEXQ+WyKkCI4nfLYX9VHAdALZIU78x3JUKIiTKzgvixoOlvdtV+nfEB+pPjAu+IDC0XNZb+g6JOVWmn9cFvro+xT9kIrImbWqBw56qgXVEDVi6k6MXIBkQsYIQ=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 4,
			data: "eJxjYMAJ/gMBblk6Sv9HAVjVjkrTVxoTEFBGP+n/WMGo9MiSBgAOV1HL"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 4,
			data: "eJzt1DsOwCAMA9Dc/9KuOiCSYJulEqoEE+RBPgvAgRURFhXHWO9e2bwiLXGLVl4e5Pom2YZFm85+wTBcsnzIoblEGvdZ8oHMucwvKpkehfF6lIldvsyZKyxuPmbgARjOwmg="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 4,
			data: "eJzt1FEKwCAMA9Dc/9IOJkNnkxrB/Qz7aV9brCCA4gVWJDyNLnyZ61FqzSTXSkY9pjRnpxyrcV/IPjeXT9aX8OWdsyV+LgPO5FvPZNOOrDprZDehM0m5uDUpF9skk8LmS/fFbZT8FY508D7ZtCMrt+UJFRcCju5K"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 4,
			data: "eJzt01EKwCAMA9Dc/9KODdFZExuYP2PLZ32tUhBAyQLPpAwtjtEOMY4hjprAxip3U4UwOn2X6fWlqSeOgWPOA8PEVbzMRKfMnS1Mc4m5mGrOO8kV+m/J4XQ7pGVyWwx/3rdMGdf+xFSWmT8qB1WgYNg="
		),
	],
	"R": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -0.5,
			data: "eJxjYMAO/gMBDimqyP1HAtjUjcqRJodNLS3l0Nn0kBsI+wdD3FJTDgDIkW6g"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -0.5,
			data: "eJzd1FkKgEAMA9Dc/9J1Qeg0JlVcQOxXnTd2oogRDxYAL9qw1dJKSNeQVpaK0d7s+yFHJzdxv2DhjN77GYOz8boYZct+H5qfRc2/bsPZIiff21jddy/bP74Xmh2iXjRF/kezmoG5Jrp+hZc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -0.5,
			data: "eJzN1MEOgDAIA1D+/6dnMj0ItKXGy7hZnm7DaMQyKnZ5apKRylNMdoUgVE3mnMmeIQjX8NSrMain5anw1O5YCk7nMFUhVUlKFWDgQtInWHcD1wOoashVe9vpmqpXggdcw0mtD0p+jzn9r+qiVJUjaKVODjd3h1ypf+6pSgwJy1FteQGcvGy+"
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -0.5,
			data: "eJzN1EsOACEIA9De/9JOWMwEhra4cCE7yfMTRIHlAxEjcAgpRkANeoygmpyj5pfohqw6gi/rCrUHMIJI75fnBgB+RcpI8CILkMtT5g2T+squO8hhBNDtw8GqI9EPZ4B8F/bc26DuwkH5eDRAGTLQ0gQocQNgFy+QBWEeSif/HQ=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -0.5,
			data: "eJzd00sKwDAIBNC5/6UtIYuiM2oKaaB1V3nED9bsUADoBWqFO+Z3SYYSLyKJVHBdFtRd+npW3ne5QH6keMFR8YKFouKyXqEoyUqN5BPZ1Hopsc/3FB+onlE/KJWppE/4dP5bPJjpCxe9pnbcvSoelW7xuCqQ9WKqToy4AN62bL4="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -0.5,
			data: "eJxjYMAJ/gMBblk6Sv9HAVjVjkrTVxoTEFBGP+n/mDz6SmOIDC5pWiSHwScNAD35wU0="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -0.5,
			data: "eJzV1EsOgDAIBFDuf+kxLowwwGBi44eV9ikdTCPwQpmZxI7tqP26s/OR1hzTauT0gt9fNBu4iansFwzBoctCtp7DCjHP4m+KOdP8cat17JOUyVOHW0xhePqc9Qp/4SgOrM7awPmjnswZUNYjXCskDj9mYAOvMicE"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -0.5,
			data: "eJzd1eEKgCAMBOB7/5c2MKrlbtsNCiJ/3j7UqSCAoQ10JDQNM3SZ61XGmkmuI+n1Woo5SzmOlntD2lotj6ouoctZkyV+Lh3O5F1X8tKK3HU2kTwJtSwKpI8zSd7SEjwibRbel8sVOZrSZqVMO2pKt4FMuhMoJfqSLBO2deSZbPxWX5YWl/LUkpx6A029IBk="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -0.5,
			data: "eJzV00sSgCAMA9Dc/9I4OAga0o8MG7ojfSCCAihRIWdChl4ZYztwZYxw0hD7ptpNiWBy9V1m5K5pnYxBxtRGwvBRHGbYWebNHNNdYG5mTY5nCiW/Xn9x00z3TrteNoXHyvRwl3H+ZREuG3qcZWjjnsEP08baiIb9ckeYoTzzuMhUdgFDDbF5"
		),
	],
	"S": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 3,
			data: "eJz7////fwYs4D8UUFsOXR0yGA5yA20nNjW0kKOlfwabnbSWY8AC0NVRSw4Ay6ddvw=="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 3,
			data: "eJzd08sOgCAMRNH5/5+uC4kWudMgwY3dnvRBUyI2hiQvbGphYbAZmE1JZGfzD2KpzFcsxvjYip3cuXKW65/VmkFvPSK6XI2emoP1M/Hc1+vIqPf6Hrcb0eLd/fL/MUQ6jBdxAIIjdLY="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 3,
			data: "eJzF1EsOwCAIBFDvf2mbfhbQGWBISGRXeUFB073lWJq6Q1OZfDLLRlomhVSB9OuRxDUG6R6aMolCfUkozwaF1SdVBdMWGJs5XO8takpuoZCqG7/Xo0MZ2bTXgvmWDsdr/y+LdxQqJ2HNPxrxF/ImqCIyUCiT2UJ3VBkZ5p0UVDMu1Z+zhQ=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 3,
			data: "eJyt1FEOgDAIA9Dd/9JoNBI2CsUAn/icjCaKjNS6i4LIPO2lFb5si4Ld2B40R8MbcCoF2k3A+6CwJXtiH6QmiaIIFPVBJmDWGJQM/VA27VgyFDSTmYrux6BeH0v3U2NgTAi+Fsh1Nzj4hSq6np7DdhAsiy5S7P+hWxe3axof"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 3,
			data: "eJzt1EsKwDAIBNC5/6UtlELM1M8EQrOp66dRQ2L2UQDoBWqFEQJJFFqyQzDqZ0rFUCXRlHKc0vZ5Ja3dF5wSQvXq4DnIqbRPLugSWMXWK6popIJBooRZtfvhcc5f8S5VoJWXpZj//8pVKW7VCiku9k6zhQ=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 3,
			data: "eJz7/x8IGLCC/zAwQNKYalHASJUeFA7AEZmDQZpKvqRiJI1oaQasAEMttaUBFeboNA=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 3,
			data: "eJzF1FEKwCAMA9Dc/9KOjYmWJrFsY/ZLeNpWLLa2IQBYVIwezggbA4roKvpmLVO7WdmKXWbf1H9M9lQ5VIDmuO9cDqaNIkWY1PlcbqSBZ5haHA8jMvQ155CG36DCocJGFvpq8p9+Hgt2z2EsTUI15wefh6KLHbo4AKwERvI="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 3,
			data: "eJy11EsSwCAIA1Dvf2k70y7qJ4HEFpb1VRQZeq+Kpss7dBnrZ7FNke2WaSZ3vS5xjr5izNJVyHEtl0PBV4wkzlMhBZxdC1PhCHY/K7Kb0iyWUYFcO9ZsmdKKCdiXP3dXZR9OEyPJ/2qWZe8Bds9IzvqLZKMY/49mMZNwcyrh3lTCE4ZvGuXFXJQHcQHdK7+H"
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 3,
			data: "eJy91OEKwCAIBGDf/6XbIJhpp15Mun+zbyuO2Bi3I28YE7u5IJrkCyaMccxOsdsmgMGvdxmdp0a7215J0mkql538xKi7aXLkb0RhyA7STcmmRqvhamBMxzVoLoC7B+ZHEBqxz4xZ2U/zDVGRnkVlC0xcy1yGZj9K2HW0DXClOckDKl35Pw=="
		),
	],
	"T": [
		_LetterImage(
			width: 24,
			height: 36,
			adjustment: 4.5,
			data: "eJxjYBja4D8UoPNHxUfFB4M4ALjWvlA="
		),
		_LetterImage(
			width: 24,
			height: 46,
			adjustment: 4.5,
			data: "eJzt0zEKACAMwMD8/9MVBFFqKoirGW+QWmiEhivi9FyzgzhrrsPZcuVC/eVijEff95L/MP20x+/fzbMWJxvVgb/XADyQrW8="
		),
		_LetterImage(
			width: 34,
			height: 46,
			adjustment: 4.5,
			data: "eJztzlEKACAIA1Dvf2mDIipTJxFE4P4cjyERg1ANFh6iKVjoSoodKUIoQyzINrGlyNSNp08FYzGdtuiNK2oLBadI8ZlgLIbyRENAPEkB0iTUVg=="
		),
		_LetterImage(
			width: 29,
			height: 46,
			adjustment: 4.5,
			data: "eJzt1DsOACAIA9De/9IajMYf7aDGiU7AW0hIABIPLBKZo0fi7oDgFSd3cHSfL/18tafYax9rS9EmCr0TBAYeov4dzRkW5vgjGYZvTtw="
		),
		_LetterImage(
			width: 34,
			height: 46,
			adjustment: 4.5,
			data: "eJztlEEKACAIBP3/p42CCstdO9Qp5zoDFoKqAcJtJdC4kAm3XiEb3JrC16OAugXcMh+MP3//7QLuwv+WLbyB67ayyOLTAuheYK3R9X1MAaMj1FY="
		),
		_LetterImage(
			width: 26,
			height: 40,
			adjustment: 4.5,
			data: "eJxjYBgp4D8MYIqMyozKjMqAAQAlZA0Q"
		),
		_LetterImage(
			width: 26,
			height: 51,
			adjustment: 4.5,
			data: "eJzt1MEKACAIA9D9/08bBEU2JwQeOrjjXkIUaCYCBVKAUDCjehYgEriofstdLwl6ZL2UlwF11xI5jjhxw/RFJPygLS0/CPVy01i2tUoyALvSLvw="
		),
		_LetterImage(
			width: 37,
			height: 51,
			adjustment: 4.5,
			data: "eJzt1UsKACAIBNC5/6UNgv6WQyRtnJ3DA3cKQMyARDAhaih0gFhCIcWpaJZ7dOc4+GArtdMfDdMedcURlc5CuWeQBAoUyA2Rp79BAwn5lT4nASk0npo="
		),
		_LetterImage(
			width: 32,
			height: 51,
			adjustment: 4.5,
			data: "eJzt1EEKACAIRNG5/6WNICEtHYioRbmz9wnaBECyAfc0gQ7zoIEb5r4Y3SZTt82GZP0K9pYr3i2htz3zekRcvn9/xYW5JonzH/vsFGaxKRA="
		),
	],
	"V": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 2,
			data: "eJxjYICA/0iAAQ2Myo3KDZQcPjat5NDd9h8N0EIOJo9NnJpyAEZj7iA="
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 2,
			data: "eJzt09EKABAMBdD7/z89UrJsF0vkwX1bJ8tkIjSgkEOBGM4bqHXnm9ne6PLtWXP/Rq2DBma6XjNVO7Poe8xN9Y2/kRAqi+KCM5e1wf7LhjG4lARFSwUm"
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 2,
			data: "eJzt1EsKwCAMBNC5/6VTECnmP9KNULMzPnEUFBCiMIpTnQTFjlJLp1Rvt1VjhlK46k9qGZRKskf5RVmYKuVcl1M2nD68XxtfqN/BJMhz2JxJ2nCvGM5DNC4G20rUv1Sopjgl+n6Orgfk7xQl"
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 2,
			data: "eJzt1N0KABAMBeC9/0uT/Mzi7CQuKLva5hNNEQl+SAoKPHQx0BqC2nNBajMgHzwEWo5BKfeBNXPQkVXQWjWjYDYfLXUNnGo2UwCmk19gAMc+A3M1AHBQcGdEjx6OnA=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 2,
			data: "eJzt1DEOgDAMA8D8/9NBDEglduyoU4d6jI66RIjMQcKLN14YFXGEggdA0WN/qi0Pmquumiv1cS9Tp6Cc9ilVhzuqTNulwMV7RW5Qa/VmIHx/2nw/EklYr1bk9cSBI+VQDshBeQDWvxQl"
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 2,
			data: "eJxjYICC/yiAAR2MSo9Kj0rjkEZVi8EZcGlMr/xHBzSVhqvBLkMLaQD25Gi0"
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 2,
			data: "eJzt1DEOwCAMA0D//9MuoyOwFajEUDVjDsVKBshUiBoZo5J5xk1G4mmM8CqlyZB3P3+eGbhM2WEcc+lssHaW+5fcHmuC32Mao0yvBO11G+yvW/LjT8fXHOx6Pe+FyWE="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 2,
			data: "eJzt1MEKACEIBND5/592QdjNaCcnMOiQp9QXUgcBmBZYkdA0QuhyTk+WsZbKry5J722QuPLKKtmlmTS+SQrkgGtkb3/qugz1lkx2JpnC5LhcjMrWjTfpp7C5BL8vyy0z26WfVJmHLl3L8rR4AOrI70k="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 2,
			data: "eJzt1N0KwCAIBeDz/i/dCHSKyx+2ILZ1rtI+LLoIQMuCmkkZznzBSCcy3M1M35hksM0/jRShoXqWse6J0eqOkR4vK0bnMtsc451vRlSM+7Z064FZ8Pc1/dP5JkzFvCAHW9dd2w=="
		),
	],
	"W": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: 0,
			data: "eJxjYICA/0iAAQ2Myg0NOWR6VI4yOXoBZLvR2bSQAwBtUU7A"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: 0,
			data: "eJzt0zEKACAMQ9Hc/9LVQdDWfBDBzSwiz9qhGoERQg8CmN6b0Er9tP1ulXy7tLE607dK7nyQrfta5fpeWeoB/c38l9Fby+/m5H872b50NhROA9weZbc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt1MEOwCAIA9D+/09vSQ9uQpFuh2UHuSlPNEoEDiPA8FQnYbFfqdvMUo3ZVjFjKWz1hdJPnNWo2qnUCFu9VsxqpZdkpWp7Km6yPmddu1Tx3yxUuKnEYqs7aq7LvKc41OqCZX6ShnoYJ0N0NPY="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: 0,
			data: "eJzt1MEOABEMBND5/5/uhsRu1UwrTnvQE/qIUADLAy1KkKEfg68vwRhLQRuuAC44AusVRTBaF5yDniGA4AiWBUsA/1wEoJsPMwXgO5qPQAF7PwUNYj1aCcyVMTM850wOtuMBHIzPTQ=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: 0,
			data: "eJzt1bEKACAIBND7/582aojMy3NoaOimkJdBGJkVAi16tBAKeEKFDUHRtk4dDwfNVy8oaDWXiQrLr24qbrIG4QHLvbRTNkQlZVr5KleuehzuWbU1XO3ZL4Ar3zAxlf9hKClKaaxLNPY="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: 0,
			data: "eJxjYICC/yiAAR2MSo9Ko0ujMEalB7f0AABUh2BwaCoNAKyCulQ="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: 0,
			data: "eJzt1EEKwCAMRNG5/6VjNwVNxk+hqBtnJT5jRMQIilCR9YRsztrJIi7bdOy6fGR16y4f4XfgWZd/cFFfFMDDRK31XdZxOk3MCuybG27Oc36xqV0Novm3EhNSGuLsCiE="
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: 0,
			data: "eJzt00sOgCAMBNC5/6VrUhOt/dDRaIIJs6O8UhYAQLjgjgSnYcLLMZ1Z2lorjzolde8DiSX/KG1DJ8/jGZm8ySVnkAoqWTZmMse8tDdpZTLE9b4jJVRKGf5FpOLCSzdgN7zUdSkNHpkrJ+WDbPvP0Fo="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: 0,
			data: "eJzt01EKACEIBNC5/6Vbllg1NMeFIIj8iuZp9RGAxgo1QxmkTjC6k5lvl5k3WGRwzR6DipHlNftMDyMTNnjjWcXoqalxY23PKjN7ggly00NuhpFyPWaa/U4xm8XWUfOnHoGifK4="
		),
	],
	"X": [
		_LetterImage(
			width: 28,
			height: 36,
			adjustment: -2.5,
			data: "eJxjYICA/0iAAQ0MZTl8bFrLYXMbLeTQ5f+jAWrL0dt/yHxayxHj36EsBwDP8J5w"
		),
		_LetterImage(
			width: 28,
			height: 46,
			adjustment: -2.5,
			data: "eJy10+EOgCAIBOB7/5cmt8ZCuDMt5ZfsE8xUMxmQ0EKCMJw3SEv1D9XenrN1BwZlMZ+zOhch1izkaV6upRvitM/6b5G1WO07Z5mg5b4sHf06F3y4F8rqhnzM/sPASMeX90B65zhojEyLvyweF4bStWc="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -2.5,
			data: "eJzN1EEKACEIBVDvf2kHhKFRv/qjWeQq7EUmlYgSIRacmqRQ7CrlMo3y2U6tmUlJs2mpcMFnygaMcpGToQn12tiq1Fq4V9GfAwXOgFQouVEAcIqo+1f1cTaMJScIl3OqeBhvglP5OOdqTQxK1SV7la8OVFHW6oJvcls1TcJyVCYf/pmweg=="
		),
		_LetterImage(
			width: 33,
			height: 46,
			adjustment: -2.5,
			data: "eJzN1OEKwCAIBOB7/5fecKOa2Z3Mwcg/lXyiBAUcOmCRAoU2Bs8zAS7HQE8LANJlDaamdWBrBsAAPCc1Xi/GiiP/AcSQDNzXJUHS/zsY5NqNbDSLsipo7RSYRy6DnhXAfTwcvHibMZCJHcAgFDQkgZkTfKU68A=="
		),
		_LetterImage(
			width: 38,
			height: 46,
			adjustment: -2.5,
			data: "eJzNkkEOgDAIBPn/p2uaeKDsADVqlJvbgV1px9go64lZPdFQZr+gpEEoHLtAqblTi4jRiyhNJBTmvkipKhSqBQVdUaXZOBCQlOK7eJeC9Mx6Kp8YbZ+k+h+NR4GC3Kvg3rU4oC9RqnLam1S2GvddLHCLSu3WXg5+HqXmXF9SBZSsSqmOmHUAUemweg=="
		),
		_LetterImage(
			width: 31,
			height: 40,
			adjustment: -2.5,
			data: "eJxjYICC/yiAAR2MMGlUtRicwSON3S80lcZU8h8dDJQ0Tf1NrDQGZyClMdVi98twkwYAU0MLEg=="
		),
		_LetterImage(
			width: 31,
			height: 51,
			adjustment: -2.5,
			data: "eJy90uEOgCAIBOB7/5cmN7cG3EHaSv7Fpwgssy7QassY0VnNOMnomMo4Va+4TMfITawwag6ZDRYXEOIF+0w+a1yC5txmXtKXnDrvKuDn9ljXWeD8A5Lmo5GpkmarOWQ2WMx5f4QVLrI9Mz3sLnDTk/O2TcYR1iqnilzaiAtUBGXF"
		),
		_LetterImage(
			width: 42,
			height: 51,
			adjustment: -2.5,
			data: "eJzN1UEOwCAIBMD9/6fbxKQGZcHFepCTgakKaVMAjxaoSGgaJnSZ05vllMvllF9IUzsqkV81k1GzR2RbqXIMlnYDyndwT0b3j3qsyojuSToCLl2/uaRGl9vz+S89VmRv0JQ4jjbRpf+AZ6RL1uQxaWpr2d8xf04gUZfkmLCtL5/Jwt/qZmnxUnYtyaZfvmyEtA=="
		),
		_LetterImage(
			width: 36,
			height: 51,
			adjustment: -2.5,
			data: "eJzd1EsOgCAMBNC5/6UxihFopx/TmBC7EcorlgUAaFEgZ0KGJ/5gloxp1qxtxkLZYJ1njOyxaK5vbOaQBqKEGr0F7VH9Zkvjnssx8n4mWvnUSOWbPpzyhNHakumz2Kgj1MzIu+ZeYSVqpxem5d4WFnan+xr+AlouMic7AAa4+DI="
		),
	],
	"Y": [
		_LetterImage(
			width: 24,
			height: 36,
			adjustment: 2.5,
			data: "eJxjYICA/1DAgAZGxWkrTg+70O0bFaefOACujJ5w"
		),
		_LetterImage(
			width: 24,
			height: 46,
			adjustment: 2.5,
			data: "eJz7/x8rYMAuyoBFnAEMsItSWxwhjyyOrA8hjmoeAxoY5OIY4QHjYBPHFn7YxRFsJHEUN8DZDNh0kuIPVDlscYopTqt0M1LE0UVxZNn/uDI45QAAwceNjw=="
		),
		_LetterImage(
			width: 34,
			height: 46,
			adjustment: 2.5,
			data: "eJzt0UEKgDAMRNG5/6UjRKTFjPkuKiI4u4QX6FApIMqw6JBE5jkhFtN4LY5NK3KLQt8R/nfL4TohFkPVAudOtqLr3z3vpggWufWiXFeRIwmTX6wXwWKoTuwIxCvZAJ7lnI4="
		),
		_LetterImage(
			width: 29,
			height: 46,
			adjustment: 2.5,
			data: "eJzt1FELABAMBOD7/396mhTN7SQlD+7J9nlhAlgeeCRmDgi+h33NsZUpekchnkMyl7D/ECFxqmIJet3scMOIN9AkekehEaxrgVM+rlD/HRafIeMcb6QArEoXFA=="
		),
		_LetterImage(
			width: 34,
			height: 46,
			adjustment: 2.5,
			data: "eJztlM0OgDAIg3n/l2YxxsxBWzhMD8Ye6ZfCft0LmXYPFTYnbKoE9hILnIkYtxKooWF9nyCHeK8oIue1iVCIRB6dTI0iOyvHwHm1JIGDIKHfiNpe0usnXieIfRHc9ur3fVgDM+icjg=="
		),
		_LetterImage(
			width: 26,
			height: 40,
			adjustment: 2.5,
			data: "eJxjYICC/zDAgA5GZYaYzCBxDorsf3QwKjMoZQCp3O4g"
		),
		_LetterImage(
			width: 26,
			height: 51,
			adjustment: 2.5,
			data: "eJzt1DEOwDAIA0D//9Ou1CWGYNqBDJXKRg6ikAHSBBxYAUrBHe78kEhJkNAskq59FkjJZ4RGtDcIh2QlKvGhK8kDbHOBfCGJqdFJNVgv9Wf8MiLbud007LbWSFzT0xcU"
		),
		_LetterImage(
			width: 37,
			height: 51,
			adjustment: 2.5,
			data: "eJzt1c0KwCAMA+C8/0t3IMx1rE1zqPuB5dbw6UFBAVgZiAglxIyECFuPTlOOXEHR3lVo9G0In0V+ZmhWNyPPCIobRAuRIHZ8PVdhEhp9huy6R3IQfSjKj16JxKf/gAUy8Vd6OBv6rF7a"
		),
		_LetterImage(
			width: 32,
			height: 51,
			adjustment: 2.5,
			data: "eJzt1MEKwCAMA9D8/09nyFaYrE0YotvB3uKLBxUEQDXwLiuIcV5UPvFbKP3KytvSoOPvzuyJH3vWOJxHFt6f6MWdFBXhdN6WjDP1M4x5MtvnOp1HRbj/sdfOASgaymA="
		),
	],
};
