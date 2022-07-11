part of 'captcha_4chan.dart';

const captchaLetters = ["0", "2", "4", "8", "A", "D", "G", "H", "J", "K", "M", "N", "P", "R", "S", "T", "V", "W", "X", "Y"];

final Map<String, _Letter> _captchaLetterImages = {
	"0": _Letter(
		adjustment: -1.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8CGJDAfzRAbTlkMXR5asvhs58ecujitJRDpmktxwMEuNxDCzl6xR8+Nq3k0N32Hw1QUw4A+V+fMA=='
				),
				_LetterImage(
					width: 28,
					height: 42,
					data: 'eJy901EOgCAMA9De/9LVmGC20kJM1P3hU9jGJH8JRDgjgjXcQXFIbAzN5B3NzxiKsZnZQ/fJNuds+oRkPU9/VqpzYU97y3E3zvCFxVxeqf9aJuvf9764Ox+PnGm9eytrOwOr+VAr+84572aAgVj/LZpwcABFUkfV'
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzFlFEOwCAIQ3v/S7PEbZkWWsmyZPwpT6iARvxoAHoUHImZkuDpwmIyFyQ3FourpooAPSoMdecviqLUFrFfUpxUUssVdhQ3T1DDI9W3+ibt8vcopCESFHbh0gHD9a7Qolw54pmv3JYqTNm87ykGJWUezrLhKBYHmi8+Wxc0ZyAFWgfr3PaNi5hA+9PaMBmcNg42uxsQ'
				),
				_LetterImage(
					width: 33,
					height: 42,
					data: 'eJy91EEWgCAIBNC5/6VpFTHIgLrIVT2/IpMvs/8GgBH0Bj7aSWEWgDgXgVVgWXgL3nK54fJYeb9TwFVENnsAI4jR8SGL8GV2qacRNIO6k8ap3GYEQyctML8PDPxZRF1dslvApgbikDsgfoZ8H2qgs+OCoiotHoFIB/KfJRdn9L09SkG0aA=='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzN0kkOgCAMBVDuf+kajSTlD63TQlYKj04h4jdrjF7s6wKp1Mjr+K2JDZiOQA1W6gIqnVy3P2tflawWle7JKjcZKskMWCnusSmJL9xXjiZUBEzZOkWfb1XV6HnUjGM1n492brZKhI1ARcmDTa1w84mCXTsUKtwrUQGmNT33bzeXURt+5yworzraAFDFHA8='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8KGFDAf3QwUNIoophKaCWNw60M6GBQSGPI0EkahTFopHlAALfzaSpNn/gmRRpVLQaH9tKYbv2PDmghDQDOVQYI'
				),
				_LetterImage(
					width: 31,
					height: 46,
					data: 'eJzNk1EKwDAIQ3P/S3eMMaaJ6drSwfz0BaMpbe1vhQ46q8cMxlONJZB6xyDMOl14BSNhOrCedTeMFWGXng9BsURT24J1w1g1aTWHJYkZjE9xb/Ot0UHSy8nSFApVHz7NXsKpM4Fjp7w/+Y7h6ODvkDERm299YZsPGXD3ALTB0ko='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzV0kEOwCAIBED+/2mamDYFlgUO9FBuyqigqv4wRGQupdHiZKXvrPgojoXAJnyWynSfudQtecYhQWWWWJNQQCX9XU2kzOXJVR3x/9A8CcisLCaxrB0Zf22Gk1W1nbalc9lcqpqfDNINq3f3P+oLCXhHlr2HqUaa+XfApQbpI2sA6qHyzdqV9FLYuQQ/nbHodsu0nbkADG/BaQ=='
				),
				_LetterImage(
					width: 36,
					height: 46,
					data: 'eJzN0+EOgCAIBGDe/6WpzZoXHHHZ2uJXyhcqpftfw/ZQTMdsRpcvWTaoxgAy3OS3PzdjxFpFT8vKrpiwXGVw440xxRi2Puy5+4Y0DcYUcxsPza3lnUtKMX0DGjPmmfH011Hj/K6vmujemPpWaWbOnY+KwUi1wzLV+qGEYsreHrsmBhlPX90cbmz5Qek='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzV1EsKwDAIBFDvf2lLaQnGGT9Iuqiroi+JsRDV/4dIT93RU5WULZ5EybKdbdVLYZKvQhl1MpPi5M7JXYJhRJlaxgPG8XCXSHb3ukWMsUy4hfnG9uCjknwfksWo3mpjqM599qNWuiXp/qooSSfK3EEJ6bmEFyCZrS0Eh5CznHQ+f71x51z6BejW01wobIIXL7doymA='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 44,
					data: 'eJyt0ksKwCAMBNC5/6WnUEXng9CC2fkIMYmSFwMtQGQgCCOkBJyAJdPWoYUmbNGmvGILTLhvkHb/yzzkXTIhWiJiK4dEtuhq5n5sMnuVsfwPgpZcccvpYdCS3bf4hPphvF0Zcdei09vCA9vJmHY='
				),
				_LetterImage(
					width: 18,
					height: 45,
					data: 'eJy90UkOwDAIA0D//9N0o8EYEqk9hFtHiIJjtqGAAqcgA1IbvPT7ahN4u3xGFuvEMcRIoIJOeIe4EAuBSoxN59WDn5Ys+Cd1sob7NcuJcF5tgPwjFeptk1tlCb1Pl5SXG2ICtMpdB07hqWU='
				),
				_LetterImage(
					width: 43,
					height: 46,
					data: 'eJzl00EOwyAMRFHf/9JUlYgCnvnGkdJVWUXhecCOMsbfrYiui4uWFTHXfDy6r4k7XArCLZNt3VLgpK0ylA5Qej+nAqSaDee7Pl1LJW3AROsZa0MkH1M4X9qClig7U52Mp9JDq8V3aTGyjcJ0R6bwIXydoXSbX1C86fFHW183ExsUztnmqhLneqBrdo/C7YfsErzaODvMJpezC7dlF9sfIGojFg=='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzNkrsWgDAMQvP/Px1dVCyPZnCQyYO3mGC7f6AaIKcGyAarR+3IWjWjSu3xvImBt5mwQqo1tZqSYlNh1uEw3YulzJJudHTD6DuK3VyhDrseIlWOapmV/xpR5pOD8cPqhaIuPqNk0XQJJEVepsSx4cXHo/gb+y3aUkGiC0PhLGImHWgxjPFZvgJDLeYBEV2sfg=='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzFlFEOgDAIQ7n/pWeMW2TrA/snXw5fCu2MY/xfER4VPRgLasE4yoIUuzvvy4JSCZY657TUygtHyiJkQHseNeASOKCK0l0tqdzE5aVbOwRohu5QIVVRO6xbpJBqaGLkW5bwKMowHz+C3s7VpfnUQAp6xsDOYaGPVDYQ8GmpAQ4ZtJ7nauAp0/8ocJhw/c+1lyETW12OVq19'
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8GGFDBf0wwCFSgiWNRNghU4PQeAyYYfCqwSA4+FWisgVDBAwJ4nTtYVJAS+wOhAk09Nu5gUoHNe/8xAS1VAAD8cVfy'
				),
				_LetterImage(
					width: 34,
					height: 50,
					data: 'eJzN1FEKgDAMA9Dc/9ITQdAsaeuqiP10j9pmsDH+XchP98pPnwhcaiiDqVsCs1DrdmwLsJC1g5ambSXicNN0ekK2jYeE2CXhGE8aC56+JfCNKHYpYqvF+atFMdNJSDO5Fxbu4vqCvy0KupIgGF7jTUHDpMubbiTCt+kQSbouZ64NBmVY0g=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzd1cESgCAIBFD//6dpRjugrLvQ6CUvlT5MMc3sD6W1VtO9KDZrEVHUA7S18AHHsrKgp0fZ6dSS1HZYm19OMHSeAPy6A9o35/Qy1ysafHVMj2aRE/a96WUG+r2mNRjkUR13CQ5AoSygpjsr6VrWtbZ4cIJ22CvWS4pvaRBwUquchEqtwVzH7V6z42CrwU5DB+5H7YBnRJMB7wNM/88TveKIqe4B8kF9uw=='
				),
				_LetterImage(
					width: 40,
					height: 50,
					data: 'eJzV0usOgCAIBWDe/6WtVpvcORa1xZ+CvnSCY/wmaA/UIZZ4PHTkBOpIAenYe7oQq3/kzlTWI+fUe5zeOnHjHacHFrvjW3Je/3KEfQnc9QRcFbdc8YeYVrEq6pDedDrWZevUtQhnx0rdztgGl513xc3yTFBHqTP33jRt1Xk7ok6HFpETNhQK83wDZ8H5MQ=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzd1UsOgDAIBFDuf2lM/CyAgSGCG9nZPoSSRlV/GSJteEZfbmtxcS21aF3BgKgF6ywV6bytgZagXQ48XzqmYq2jq6E67ak/6ZqWGJpfOKBhpbe6zDGYVjBNfKLRw67mc3xAb+oaPwdr2nQ81TAV6aSQujCrNVW3sabBxlCDLfwC+KK0nNWsuZYOSfSfhkowze/BrdMRF8HkAWzWia8='
				),
				_LetterImage(
					width: 20,
					height: 48,
					data: 'eJy900sKwCAMBNC5/6WnpFRMJhMQF3Wlj0A+KvnXgjOoIgwtClljB8HYAVX3ydnOPhudlcrF4AxiC2tXvLbv2POWxk6trTbcMZrOtGOa0dSrXnd8ZnCmOazRGWeDs9amMx1HearSVYpKZZg/8Rb0AJe1+xM='
				),
				_LetterImage(
					width: 22,
					height: 53,
					data: 'eJzF01EKwDAIA9Dc/9IONlyjidB+jPnXh2zWasQPgROFOG7tjAwSUlAeafqoefZK9a1Ep/Uu+pMTRdeXtQMfaJ5dZbU1Xk1o/2edvhNetT9hm9nmaNQ4VHiVGujFN1RmqSi81p7Up22jtKd1Y2ghNZPv4lb3qfoCoJ1XxQ=='
				),
				_LetterImage(
					width: 20,
					height: 50,
					data: 'eJzN0lEOwCAIA9De/9LMZUFb6GJM9jE+nwQRjPhBAIaGocgwSUVGlzv13SCxbJ1QF96yIbJgQzd4k5Z4HDi3Wg7SiM7CzSyrquFrc/f2XfFiSup82YHJ5A01i26xMVlCHwPbKiLvm+a+d/2Ludcq3NkTF4kBGgM='
				),
				_LetterImage(
					width: 22,
					height: 54,
					data: 'eJzN00sOwCAIBNC5/6Wnn/TDwGBdtElZPowCKvm3AKYVuyLbproeVzhbFQbv1b2GnNbk9UyIUjTknxStatnmqJHWDVqNBaQx2TkfhxrFV+prMCrtlRcT+n1F9dYsGuW0SocMA2KqzGnaSsY0VP/T6neQJ8MSCRfu/mi0'
				),
				_LetterImage(
					width: 47,
					height: 51,
					data: 'eJzt1dsOhCAMRdH+/09jQrwg3adU0Dd5cpJVTwuYKeVfU8vsibWTj8psX8dzglbWlFGG8VIZT7iwTZHQXIpcJxFvfvRFEYcM3QsOz1OOeA47HtpVPtJzXPYCO+Ozdi4zgEc3ByfJchzrXR5t5xqXhwX3U56tz7r3AQeuW/qGB507Lix9pKM357gMnOJ4jQX3Y0W8EdgfczlOAaBx5Sok+G/0Idpeu5ehXUgINtgzAUY='
				),
				_LetterImage(
					width: 52,
					height: 55,
					data: 'eJztlMkOgDAIRPn/n65JU5NShgHtEg9ya+T5gC6l/LEnRGQ/IzXuRTa/MT0b5tdc6X0QFS/at3S+RmcZUEmaoVbM9EuLBgzU0dKcwcwxicmAbrnbZ7gBMhnkNEPagXND2pthOsTYKp60l2Kc5XeYaJtGhm0tPObsOACtfqBHBpf6hpGTDB0AYPyJ4beDIe6PljKkYHMOEk2aPU0xWhd2CXTrGXKtiglbfAAYH3sfEaN0Yf6oi5Iujn8EUQ=='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzVlFEOgDAIQ7n/pTFqosDagsl+7NdS3zogc+5/ls2oU0OsRy3IOW2r5uSFrvz7sU1+7Q4dk5ZJZ+RqExLZGFUeCiXHSJI2L9pJvm5nQCKf1A784jyrfWRd4ULLbLuWAMmPnzWvx2dJYKLbSY/CoCaBu5GEmz/8nCnA0gXxojyncqk6krzjtxlQWCNNFmhKk5klWFGBrPYB/pFqzg=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzdldsOgDAIQ/n/n8bEGMW15ZLMF3la6BmMzkX3X4XZALUmbXdspi2Gp1uMxYw+cbYnyo0OQWjgI9oW2hOaCJqmgsRptiiu+u2lMwsxudJUEedo0dxYPQ2TIPUst9OwVHOC+Q1XKJ0cZWBK4e6M1vdcXucG2t+h4JJm+Q9oXqF+QBL36+HIczh4CN9ug5a/tzn9HlZNqDvk+FK1qA0dCjLQKBxND1bw'
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzVlEEOwCAIBPn/p2liohGdBQ5eyqXJOgUWjO7/DTPrkzVsC6xgu6INAjq07VySlEmmvEq+I9fkRaNggO2T2icd9ypIMJWBneKQQBgCPXWO4NxNkzSIJ+TxB3W/TzsFJ8qzg5b6JO8jCPXiDkWR/MAkpAsS1TJln2zNSPYkyGB/fDVIFyMj4775ZTKIoYuURV2Cw11J4ZS6nMX4AOu+ZNQ='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzdlUEOgDAIBPn/pzEx0QrOIhhP9mRgoCzF1v1Py8xmdCvAFtyIGNKwRjDiu/WKVDQnLFLD7p/T6yxl4ahJCeV+zWgXIyNpFPqSdnSo1ExHj+wIlli3L7pupvxPlHTmPqdvYawnHMgTfOCsX4if0aK3QzparDUQ2abp0z6iMyw3JTMLH9PdZhcVatpDW/aPEubJq+k8TA+3bJPOu6/gznUvK8aAzvvdygoR5NkABNpM+g=='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8OGNDBfyxgKCpCl8GqcnApwudjDO8OE0XYpAe7InTmEFDEAwYE/DgYFf1HB0NfEYYerPxBqwi7jzG8SydFADJJ0rM='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8JMGCA/9jBSFOIKYlD+fBQyIBDJ84AG94KcSgZtgox2UNSIQ8YEOH3YaXwPwYYpgqx6MQlMvwU4go1zAAbAIUAGMxrcQ=='
				),
				_LetterImage(
					width: 37,
					height: 55,
					data: 'eJzd1EEOwCAIBED+/2ma9NDo7qJIy6WcrE5AMKn7/8J253dswWtkY7iQJiOLrIiEJ6SSHiJD5ITi1M/eqj4jPbjhE2ZLj1hCcgQJtOiLooQkxe5WCNqpI1x2o0x3CbSdewqNRc8Ra0QiJT8wIIewLxDstqH51xNOFe7cgOabyU5kvgiR5BcIR6ZripMLx2INLA=='
				),
				_LetterImage(
					width: 41,
					height: 60,
					data: 'eJzl0kESgCAMA8D8/9N1HA7akkitwMWcOrhAQcz+EiCFzkyCuDIBwsc4h8gbiE+QTiKQr16BfqhVBPJN6lC1raH5CGiSzYDiHnNwcF6SMpQ8nnoEb/Vm2Nf7YPZ6chCpH5mG9waqkE3poVg7B81HQKNsFozj6yHCA6MT3be4xxoYW6fHS0PdgYbDF9Igu2SZJ3MAuNfVYw=='
				),
				_LetterImage(
					width: 51,
					height: 55,
					data: 'eJzt1N0KwCAIBWDf/6UdrBhaxx8ku5p3s/OBFY35L1FEVCCjEtGVxKxCZoj2CveAao8CohtHiDlKgXAXEdtTqz4xV7uIjuTJegrNhO6QkfDJbK2hkET1ZQsEjt1C0tPF922wAnmjV0jlRlOE1e8CkrXDqPAEdwlUHSRzYl77MNGL8jMgmYdiHg6a6DwRGT2RT4JNeIrRi/BhlAVMdx8qMnPT'
				),
				_LetterImage(
					width: 55,
					height: 60,
					data: 'eJzt1uEKgCAMBGDf/6UtcBXTnWeDi4L2r3lfmJlU61+syl5J1krJjlTxpWIWK1FRhipIg8mJ2GxSSVa1zJpRgDF835cyn7rHhgV9hoHPS8UsRJk1h9wK43Wlk6xdfoGFBw2m8DaLMvUe0BkvYrnNsszczoJsaPV5zPy2+AIDVMgCCYefZX7YN/hfDnlmws6hLi5jLufjKsaWglBrT1mAF/KR7dobYJ2B0w=='
				),
				_LetterImage(
					width: 44,
					height: 55,
					data: 'eJzl1EkOgCAMBdDe/9KoMSYtv6OWsPDvgMcQqI7xk9CZis16EmmxpKZiCcxkeeOTNfbdY++Oeci26jKtFo7h27HYwtu22WvUvzOrVDXr5DEVm8l7G0+TRRCvXrHZe9tt+aspFgrPqQnRucqi77PBPay0bIS1KpYiq3xLzo+7YvXdKxaDyLbSOwhmiI4D00HNaw=='
				),
				_LetterImage(
					width: 48,
					height: 60,
					data: 'eJzl1N0OgCAIBWDe/6WptnISP3JKza1zp3yE2Rbzn0N7UE9A02Of7AI8OUE9aaa8WL337hE+9+eOKkbeedgKvgZZz5M8ldse5g8QekM0fZjiUJ/MZJ99B9GeGoN65CMs5M964OUOG3FGL+mtnt6+fZ9TfF2rl6inhLf+J9e4Pt47yGhvxIKRvzfFUHfJrQ22YLaQ'
				),
				_LetterImage(
					width: 51,
					height: 55,
					data: 'eJztlrESgDAIQ/n/n8ZBzxNI2tS25yKbJY+k6KD7X+0yGxKfNSjfhVip61DWd82iBiGFnEFATMf5YmzpSuOIAaTkw9tt7MTw6SiSr9dDqr7sYDmS1TMIGtFAmOsc0iMjIZllg60IfNqEaLu+RfrreYc8I21CYr5FCBuAEerppWKjr/fcW47A3mcI7NI5ZGDLOiFKWhkBqPJ3QdwERPvmLgS5MTEJyCUHgn+CxA=='
				),
				_LetterImage(
					width: 55,
					height: 60,
					data: 'eJzt0kESgCAIBVDvf2lbVJPB/4ICMy1ip/EAtd7/2IrWlsEZ5ayNUciajmt7hXiayjzINA8zVKa/uWLGWZOY2r9WlPnKJTHn8DOm7slmgIDrrGJKRBmuM2W8fQKztVTOpnK8LzO6LmXe53vSll49wKSpY+9ZcxmtwpjRfIdJ8+TRowKif7Uyhr9+gI0aV1RMpuAhLEZmDzDk5U4OM6f1Mfe/fTPclQM27CzrAAQ+lr4='
				),
			],
		},
	),
	"2": _Letter(
		adjustment: 1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7////fwYs4D8UUFsOXR02tdSU+48F0FNu1K5Ru4iRoxcAAH+PLe8='
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJyt0lEKwDAIA1Dvf2nHYKDRxLVgv2RPrLq6Lx4z08LNvvOGFMI5hMEnsJLL4lokYtqr13kOjFSM3D5nM7rPKtgHbJTe0QoKE6Tt767Z9vogO7/oY3NX82DdDt8FryOeRTOzTKkiQuqjAKa2diVU4yuhG5Pg8795ANvqKwA='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy91UsOgDAIBNDe/9I11kQLzExHE8sSXsrHhb3b0Tx1hqeUHJU2h3xGQqiKjHkuc44/mRJixJRY3IY1UGrJ9KGrUmyrGgVH0e901aPCt51KTx0rNVEdmSg9srlYHLndy6pe+D55ZG/z9/fJCo6MFIuflITelkDavTfLjwuJ1sZ/IMoD9UFK7g=='
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJy90kEOwCAIBED//2lam2ghsKwkRI4wItiKtMR4gwJkvvTYAQ/roMAanQPGJBITN833ToCcAX5HYrK3vQFmloH4u82aAcGf5g9TYEfTD3jQvTC7L1JgauXNK7MZsK7LQBiNABu2hjNtjS5eBsRvIFjoAU9yvmw='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN0kEOgDAIRNG5/6Vr1IUt/QM1GiO7micM1dY+Kkm1UK501XlOya6go0xZMc+dBabD7lblm8Ii95UdN76Ll9IpaAvzprYu0nGOIp3gx+WqMCYsZ1oxa+pppEX1fvD/fJYiUvlbdzmcGZ8TkeKEqBQKxs0iBidBzXmRWrDCay3FqJygq+LaAAr8S+0='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8IGLCC/zAwQNKYarFroIX0f+xgcErj8AvNpQfKXvzSo6ExCKxFlR4AAADLWLlj'
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzFlEsOgDAIRLn/pTHGaAszQ9EuZFX6YPg06v6DmVkJFbbbzrNiI0SyCafbiCGBOij2ApMuH4cPWONxRJxXWGCizZWDHiSqchFz1sSSlrjT1hIX2rqrGm8spNn0xkt8aktuK30lkDNjohfjcjGCbTJf4xyI7HJQlv1uVCUxu2K8HsME5amIHffD8zc='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzF01kOwCAIBFDvf2maaOICDItLyqe8UsZEoldV4rJWXNq6NctS3jRPIyk1b5lcnJqzxdEF2bogrZTKt0kZoeaySDr0N1l79+VaGuGSoBzdaVroFQRTQOmmSOTlKcq4hSNp/7gHnAiU6rC4dDYEKXSJ67nM4qN3sK1zOz9d5UTbW8/clV1/VaVGAQ=='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzF1UsOgDAIBNDe/9JorIkZvlMllSW80GldKLK7xlmMid0cjKeSDVCMUQy7ocNOysLlCya8b2puxZgCMZmY4JvM1e8xwYedYxXFNXYFY9QUk/omS8oYO+4yairVo3XcBo24Sa3xq9+kjmGvVn078r9juWzVXwTdAf++kqY='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzNlcEOgCAMQ/f/Pz0TDyYrbTeRgz3CsysDJPPXiogRdGtGPSTlA5TUGSlwVl5rBmIl0iajzpFNr5Jiu6QrDQ5iKYVUSdbaPiFGNMfPhXKlD5I9VvvTF359gz47mr3YJselp+TOsoenoo14eq/7hIPbVFMZDmY4FkWKDFS+ItV3MI4jqqp7Ady/VFOKJL0nJKeQ1BTvpNIFvFxK/A=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJylkVEOgDAIQ9/9L40mBjdal6Hyt5dSOohoFU5QARWdLyiMLCcVhaHU1kDi30eatU+23luCE9kBTuqemHoQAWqBKq7+mwxBzA5hMx6S5lecvF3SEn267+LkP8x6Mh95AE9gPt4='
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJyVklEOwCAIQ3v/S3cx2QRazJAvfMGiUPI6YEAJhGBFvoc3DMAAsgSDfNkmlrS1Sb4+PWqFQMnwUb+NjuNqCJSgI6bCazJr5JdMNn1PSFpTETzvK4wgBZtUpxhA+YZ6q7GfO5R6no5GJsMHexNQzA=='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzd1EESgCAMQ1Huf+mqM7LQ/JToxhm7LE8hiFR9VSN1e8XwpO0DY9bi3UMqdUzRAb2OeSoDjkIX6fLpIS2zcmm5zdCW3bd31MzfZGcH2Y3UVhpI81DQ/hjyGK40dWsaQ38eLE3kL7JHB7z0znJUZ+P5NYCJpHvCEPcudRCo+RZmNf19k7hjqHXmNlfHFB1Q5+60cfXkNMc/yKSB22sDUzmumA=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy1lFEOwCAIQ7n/pVn2sUylpTVRvgw+pICaedkiwmEUFZ+9a4H8pEIANu9hag2HVM3QUKTSyUn7oak2YY3jVVsSgMeIy9nYfCDWM6Ax/CwnnaC2pCtdx6RbvdqTfmw2R7+IuoEo6247LnR28ywDQ6ODIKN0hizRfJwGUjGI8LoJ1SApLs0DMbW9ew=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJyt1EEOwCAIRFHuf2laNwYCwpfIruVlRG2qel/C1F9MlW41ZVcdIzUMKIWmU0L7ugvMwqOL6aftOtYiproj9qpmSL2KWr27DyQXRAXAVDaymZkulo3MZra3O13MHpCOZ+bKAqbOdadYVAOpew/ZHUwhHLFk/u/Zuv30Ad/DvXs='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8IGHCB/zAwCFRgUY9T18Cq+I8LDAkVOP03mFSMOmHUkQOqYmABAEzAMfk='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzFk0kSgDAIBPP/T6MetAjMsEStcApMs5UistfGaZnOifHY5XBVUR3Cy5qwcUv4LOKhmpMHZ+oQbO2UUG9EzGukBGzSIvAaNyHW6GygQ0hEwGuiOGSJ+G3ICvHdGnu/V9aED2kvGyTyClMQpJuybWJoUwGg+st2qs9Ba8fqGiHOElnKBxL+Fwf0cKKW'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzV1EsOgCAMBFDuf2lMlPCdMm1JNXYJb6BANOfwSjZ9l03TRJlPY/FF54rUKLJMsggY1+0h7goPIR7rXMMVHFrL2Vllzfn/9DNt0VNhtujNk1p1B3qm/fqkg826jvqvIVKv11D+eMqGkatrDGyjhUVt+qBhqLP8cFhv6z3NAjaNAp4ISzgi4X190RLjY0SjW+ICfUVEEQ=='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzN01EOgCAMA1Duf2nUQAhW1hWZkX4pvGw4Nedfk86ojtq6l7rQQphohxTWmcU1r6zRxxwV0DCX55wvydgtR+HO7toSnf01FADO+Ml0N+qoOhT4UvWO/ihW3MioDsHd1esdHhJcudWcmQ8dtap70inL8ErdiDPMnPX1vBjsreMaPgCYQHrM'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzV1EsOgDAIBFDuf2lMuqoww0epiexsni1gUfVPISJluKIMN01eEhsaHVHWDvqEqITpY8iKtThujUI4q7NmtrR55ho1g+ogLZDHK12oT8O5SApiOqeq4QCwrcd1p77s8z7f+Vx9Tf1FNxoXqZJy8yIdunal+orDTH8U4blJxnKPKS0+zDKXaJ1vSc/DMNGglSMaSagZ9DqUu07higtu304H'
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJylktsKwDAIQ/P/P+0ouOKSIK3zzUO8G/HP4BjUB8HlA1+KbY4xDQN3QMeyaYal3hGUkS7ZUZUxg2O8RzjG+y4ivOfWq6CKVJVpSr0UeQbpS7NXxjOGY7qwA9Z9xPiCPrzJeSGdd2qfcsEHRbvHVQ=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJy101ESgCAIBNC9/6VpLAfDXUcN8883pEBodmJBK3ovAOKR4tboaEsrO59St51rfdLzK1SRGyzqPKerWSQVWrn90Mq/6h0Imyh/H+9xjXFoc1YP9DitEMmDA6NyQ0yr6nJGJ4OYG41PU/5XLpv1D95L4QsJck/b'
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJy1klEOgDAIQ3v/S2NM3Cxt5z7Ufm0vAwqs6kMhIGcwhlM9GpecEIOxcdmwGXOzcNIAMU8B3ltgcKYuyRkV1WZqzULRMsZaLcNRYPtkL4r+agTGePuS+fEfkCV7NFn3HRgtulU3MlTG+kR0UE7W0wyLKNUB/DbaQg=='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJy100EOgCAMRNG5/6VrYlLtlE8EjV3hi+Jga8QPJURQaVV1VttZWWRVBZpXC3pdFMVlfcrV9s8VnHhDRUqx7eB+liHWVO1j5iJArUh7xzzWoq696nOs3bDvAgjU2jjo0KYei6avzgHceKsNzETrFLWBAVPbkn/TQHzQCNAAjV7cmgMrtmbE'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzV00EOwzAIRFHuf2m3XTRKwnxgIqtSWXpeCaHxWn9Y4dh3OfbLux/FUf0zIpdjiWuq+S0uec72cRUApx5ST8YTh7wodZj1Do6z1DsheyR6q9R5AaX3ecSzhYhs3QlHmXDeVqM3z3HiQ+1xZ25vJz9ZIeeKF72mvPj4ycbDG4sYFutYOXX5h13Po7Q2P0dT+0kNG50lrqnmbDMv7Z132LvIq7kQuV7yQNKC'
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzdlOsOhSAMg3n/l8ZLNKi03WpQE/dP2m9sJefU+o8qrn8pn9iZBFpabV8PMAWV6xcM9TOmcwQMlIczRKJMtlWBxyoUdIxyZKJCPmbEOmHIAmgiib5T49PcIjcYBFCV++OOYrAso+MMEX+sG0wWqMGvaRjzQshvP4z0YEY3dRg8BB+NL+oyKjL8APHdvUZukC8s2tAkL9J5IJ29w5xEw78anAtA4SU4Q/2MkcAgJvL3TIbw/5cOTB6YawKJE0Us'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzN1UEOgCAMRNHe/9KYGKOgM+1HWdid5UlLI7G1P0ZEUAdknLE/1KzjhCl6X3byuYmRqtYqaYc1pu0RsayKq7ezyeGGJAVNyu/FSBXUzUripq8HhnzPVT1ee2K4UL44OJa4SwCpTJr8evloUhfJy4SHWA6pih3prK75HcjRIiWpYVVvWqaqk3Z9A8l+32c='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN1OEKgCAMBGDf/6VXRGCw23anDtq/5OvUWZr9v8ZdAiX1mPU8UfL7yr5GFHMnEg2yQo1nLXWUsaHxMa9qYiHvuDQhratmE9qkCPgBxxqXYnFDquzzWtqi2JCF7lFyZrfo/n5ImrGt/VB0vsMzt4UyHE2HLwZWu+WNMnpAmV1PqQRRqY00krr2PJRep9Qa/poL26PfdQ=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJy11VkOwCAIRVH2v2k7pFq12Heplj/DCYiamNL/YVzuwaXCZ97ukNVMYgcOdJOD2OkxGstt8132l0SOt7YIYglurJeSYrm65JFeLNVzuhCU9kRc+lPUY9DGA8Nl6ZbRIqkbp+bJzg0clA3i8jXiklcEmttI1Qkc2vB/WO2ZfXU91jLbstwA9dzWcA=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJy901ESgCAIBFDuf2mbqUYjQXYT4q/prWJSaz+WCKeFCMhdgBs4DIhVOdrEbkK9ZgLmZl7A29A+wGrDTR11l6iBezU1wgt10dKnQDUyhxes06bjtOP0V6N78A5WpXuX3WV0/LqL9a+FrlquteN0VB81tzKQ4PQUAPrhE5s98YHUEZsTsW+s50biERjPB6ZH130='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8EGHCD/3AwBBVh1YNH66BRhCEzAhThC5jBqmiQOYcYRYPLNcQpGmTOoZqiweUa8hQNGgAAitbZUQ=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8MGPCC/wgwwhTi0onfgKGuEFNuRCvEH2zDT+Hgdh3RCge366ivcHC7juoKGYg1a/gqHKQAAOaqsYc='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzV1csSgCAIBVD+/6fJVopcXmpNsVOPCDZjzD8LapEgHqIe98gFAywjIATSSwqhrSsoKMBIvIfsG8ugcYDR1FcGGaeVkdFXRyrHEsIRAlnz46hQcxZFpwUlH0OFqz7X/Gc+feI0r2b99KDdbh45a+Z4B5GIcQoC9D6BFHofIvHPZAfNN4F78RBeF8ghzBd/Wo64'
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzV1FESgCAIBFDvf2kav0JcFiicJv7SF+I2k8j/a8zKqTY4VM3HyAzWNQUhMhBtvoH4qA3G49gF927PIIu0HdIBlwZeLgz6Bx+GfjA33FsB6FbGKBi7j2DxvhXYMN2n8FgwzZAaBWOXhaUv7EL0a6aQB6NWXWU3AtUCx1pSgri9UXYBGfw2VAyyBM5BayCEyEDXrJAzkQtTrcKS'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzl1NEOgCAIBVD//6fpoVykQJerM7d4hUPAmiKbRyHIGQRBWK0pbUDd+1hDbGjkEWemYkYQXRJN7VwjutA04jSiScYARwgJZv5KrpI0acOttSaaT1TNc6KYoEsYL6HcT+RY+7KG+DeaT5CJaqKrjYnbniCZHVJEwn/DI2/xDQHUGuIwdinmKR36Hr3g5iMipnEoUe4AgAmUzg=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt00sOgCAMBFDuf2lcSIxAP9MRUBK7lHl8Cua8UyWSnUWyqI2xK5W6QheRai1TsJjwMcm6lL1/9ZT2IZQOKU9zFlOne4NFHdZQh8HuZ02eZF0ZaYl5j2w5q3J13GVoB8uglPdYZBmOpbWsDIt5/6KwZW4TtulJzNobyYZ0QmflI8P82pNhlGQqHf5DIxizj/D4XX+N6ZbGoGtxhN3oATxaDXI='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzd0tEOgCAIBVD//6dtrum0i14wcCvegoOgK+dvRiphscTXcuqDnYcRZYFDiTRAdsEttpWn600eUeTeNm9YlZ4/xtoy/FdbqgabmK3JQblYebrFosL/RTtdQHFWvlCURfOw9WPrvKP2TujtIo5Y4qOsi2cd7wf4LWReHjpMnOChQWFbwwUEEJDE'
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzl1FsOgCAMRFH2v2mMBjVA2+kor2j/xHMNEmOMH5mwD+uJxukvEbLBj5Wmtxea+qYdsT4XxjbFFzE2q56w0vTycZB3J+apIu8IfuQPQPrg8OdyASd6beOsF2Dp0/q7B6/nNcp6gVX+vGrkmSMZ69MK5e1Z2+OG9XLT5jeGIlw1ap5FMz9zrYJJ2eAgj3z+rja1rfJw'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzllVsOgDAIBHv/S1ejJra4sCBoTOSTzpSHTez9f9HWiNHNq7Q5jqQX3xRSLKQAGPRn4jJLYHSWUMyOqcIWUqCApeeVS8ZUUE1bgW1CQx5mFD73qEC6VLEjiA+KmydPokRJzH1LibXlpF9S4mOEleR2nX3Fn+47H+SZVWk/C+taoLAmHEOIBr6gSPgk4KpUGlXV7zZqqzRXwC6KFYwrig5DheGT4oH3WABlbqHB'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1VEKxCAMBNDc/9KWIgutTjKT7IotbD7V18RBaGv/OsvM0qDXYmb3+qzqojPeNc0QgMMS4d2xzuJpPEbmVxhP6VcMkN1sXiIMN2fMmdlR0/YuFl8KMAdEjFbFtCn5ZLOnskqE2jMgLD+hLF7CdiX/5V83wVRxZSlTZvVXKDD3J6wyMfhxWzDoREhsrEVsAsOhPCMfQttwHbcwOkQANAaDfRBzBE05wbgYmAh6HYErH2A='
				),
			],
		},
	),
	"4": _Letter(
		adjustment: 2,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8VMEDBfyyA2nIMSIDWcgxogJZyyHxayw2U3fQCuOIXXXxUjjg5AI70Dg8='
				),
				_LetterImage(
					width: 28,
					height: 39,
					data: 'eJzF0dEKgCAMheH//V96ERlt85wgijxXk0+mzogPA3jRxshy48oN/WDgDF6Yefu5Foa1tE427e33yV2UudkYqx3lWXs9zwWTR2bfWu/ZxqVN/ONRRwm90Wob9QbDB2S4'
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzl0sEOgCAMA9D+/0/PBBIZW6314IneKC8DiRGnBoCnoOTcwh0xxVMQanSO6sn7nipXFoonvc/WckVaT7VX3YGn+uf8qhJUzerpAVWK/6vO5IpLptjpjzEHeuyrCk+NpaVeb3+6WnAuLsTY7T0='
				),
				_LetterImage(
					width: 33,
					height: 43,
					data: 'eJzd00kKwCAMBdB//0unELSh+jNJV2ajxkecUOTSAJAC18AAN/hEE2giAWs0AJmsA20sxYCfaoK5XATWLf8NzLjjmYuKkkPXX5OYDfCLTdBRlTqQFMj4ShEIN3k3eI12HwMHYsg='
				),
				_LetterImage(
					width: 38,
					height: 39,
					data: 'eJzV0UEOACEIA8D+/9PuzWAphdNGuUFGFFzrpwDQCzQKO65S6BWOmJhbFBuhMvHKbTXUO5XaylZOcZVy8HR6kLNYLSU9aa4E4uvqNulEOY0Oo8z+Yt2r4V9YpX8+Khb1DY+pnX/tu1XV'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8dMMAAhsyASjMgA/pJM2CAQSGNIkI/6UHjEDzSAwD+YwA8UqPS9JAGAKLih5U='
				),
				_LetterImage(
					width: 31,
					height: 43,
					data: 'eJzN0UEOACEIQ9F//0szG3VALIlxod3pi4RUswsBSlRMz2OMyzZzjUEzKftsqrVxs2QO2N94xtKDvH2YtuaiWMlxaWXEvsSep1yWUPO0/Ny25Px3P1sMeeBb3A4fcAnrMQ=='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzt0dEKwCAIBVD//6cduDGUvHppDXrovmkHylQ9+RAR4aWlJEEW+DmlpayS1mVllkB4OcxbSxQ3hMY+lG2/+b1a6rt1QmZDbic9bnruBFyVaCTBFpBEOpf44Qs0T6ek/iGtpiXOkYx0+K4ulVTCdg=='
				),
				_LetterImage(
					width: 36,
					height: 47,
					data: 'eJzt1NEKgDAIBdD7/z9tkEGOq7s5ih7Kl23uKMhgZn8MAeCKwcQhmIphjIeMp7ShaJr0vmV8DcnczJILxk/a0AgvmuC4kJloDq5ovHvpEsMsR9WwC716xu4ydnwBwqi5vmdOtu83ZZwKLw=='
				),
				_LetterImage(
					width: 42,
					height: 43,
					data: 'eJzV0cEKwDAIA9D8/0872GEUk1hhPdgcs4drbcToAGihN002XKIlkfJfZjdTspNSsa3cvNH6pSHFfDPymOQ+N+D1uD3kWv0FLM15ailhdcT1SqkhJe7iU0vesJ1xUPr3laqSQVGSlZQ2t8mveAAKGRUk'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzN0kEKwCAMRNG5/6Wn0BaS8TfFTaHZKA9NTND+a4giLSe0kK5oKZSkipYiRCGiiHLvKI7VlCq5J0XCrnfaHzT0HoQZ9rlSPMnDtdfck5iyUf0LMYVf8ST7AJrZARw='
				),
				_LetterImage(
					width: 18,
					height: 41,
					data: 'eJy10TsKwDAMwFDd/9IqtEMaJR06xIvhYYw/+jtYoEIEIpwSKhwSiLAVK34LlaeKCjvJ8vAayiFzX5e+014kXmJFmyNWjPSn4/jTxYZYsXLnC+kblXk='
				),
				_LetterImage(
					width: 43,
					height: 42,
					data: 'eJzV01EOwCAIA9De/9JsybLE0Rb7t41PfCoQrXorkLozYphQ3JG6LcVvKJBRUOTyq1RASaWTdF3LKF9wZZiKWvgvWEplIKQ9Y+W0tV1uq6E8/WHf0JOmvYvOZe/SYZgfzBtwZwR0GJZ0W7pOb6LVwtHuHBWuUS2YblyptzbSljoA28UXIg=='
				),
				_LetterImage(
					width: 38,
					height: 39,
					data: 'eJy9k9sOgCAMQ/v/Pz0To4ay7qIB+zY4tGwBs80C0GEqCrd+o+wdlWAY1IKa1FKzVqCm4PSdet5CTbFr5pVQ4wZREBBH2mxIGWGnVKcUCirMC64OlhqDV0rJP+INKjM15YmSDelp6XPnmk2SZk4rqQ2RV3EAFaK6cA=='
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzl0FEKgDAMA9De/9IVRcbWpmkGCoL9LM800/3PY2aa4tAGYs7mkRBU51ZAcWjnSl2rPgpO2dkLlb/eU6jSfbuJIhum4D9gUXN5otIbsQoQ1oKJpcqwUPE0GS3uDeVMLTGa6mtJ6sGojx0ccFkdlu9S5g=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8TMMABFsnBooIBFQxOFQxYwKBTgSY0OFVg89nAqhjs4D8WgF92VMVQUQEApIHoNA=='
				),
				_LetterImage(
					width: 34,
					height: 47,
					data: 'eJzV0VEOgCAMA9De/9KTDzXp2klAE6R/sAdkI2Jt0NKr1wJ39hagTAn8QiBnVEh5WrA1Ih4EXgvaImEPmX7SpZWoJtMVeRReKHbls7McPfON0AEOCumWVuYbzTAqETny7PbiWh1zsXuv'
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzt00sOwCAIBFDuf2lsogs/DAQLxoWzUx6txZT55ZLQF58mu6XVqYv50ExNpq77Di1nYj69fliwxhmmwFNJ0aDk09JdLi5Ty3M6roeG31oeuaJBi/mnCW9RNO5AGp0rTIMjxfF9zT5ddxK1lqfP6r6jLQusast7'
				),
				_LetterImage(
					width: 40,
					height: 52,
					data: 'eJzt1EsOwCAIBNC5/6VtGuwvnaFEoStnJfgiCQtbW6kIgKiDa/sdzvgP/eisGXMkQ06YOtcP97ZydEyCszLXkQWUu4cddWSFytF1C+fYlxOWOmonHcPh4Xnu+AC+3V4mO5nl5txFrdgAg1EYLw=='
				),
				_LetterImage(
					width: 46,
					height: 47,
					data: 'eJzl0kEOgCAMRNHe/9KYuDHSP0xNugFn2XkCAcfYKRFRhnfq8mgdZR1z2nSyO2igPZppRfuXf5VFTRvppbs1VHlEDWrR8Ha4jjyc1Rp/0Prj1KQZLJkO7GK1e7Cp7Nd8hYsfxOuRwxqg0ov8TD+jC6Os70k='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzV09EKwCAIQNH7/z/tINosu0R7GayX5GAhWhH/Xpix6mI0oyYxIWnUpDTMmA3MMOvhqd3xs5sNNZ1bj4plOJ4Jucd6NePWpPc6pFpfzdyP+LWF2WEt31uY+RdpD+cCOQ+Jkw=='
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzl00kOwCAIBdB//0vTRIsyfFOpSTdlhS8YB1TkJwGuSI6m0ReqkQs9wwYpnBpipYjTbwVXzbmOwUwqardYU02jmtxNHOU7Su83Mu2m7zLXvNqGPj+fdyoVPT7FRypcu2ftf+ICkAL1Jw=='
				),
				_LetterImage(
					width: 20,
					height: 45,
					data: 'eJzF0lsKwCAQQ9G7/02nUIVmJpZSqNQf5aBjfEgfNhaURhiE8YtBGNsNwrixnnkMXxppcyZprM1TznHeqVWwJf0ORiY/L9Ge7NrXSzcr+WpOM4W1h6p/2usUU5rSzv4AiW4CGw=='
				),
				_LetterImage(
					width: 22,
					height: 49,
					data: 'eJzF00EKwCAMRNF//0uni1qaSUaRQtGVPIRMEoz44WDRKHSFbeW4glGOKxhlqr23+/5FcTpePzdRpiqpY6nSYQ5gErSZjeAyHczZ0JRBajTVvDV40rK9hbb1lz8nRYqG04pvkQvKmlfF'
				),
				_LetterImage(
					width: 47,
					height: 46,
					data: 'eJzl01EKgDAMA9De/9JVEAS7pElBP4b97B5bqlvmhhUTe9bEujzumliHx194hM0r7TnSe3CICSeW8MeyzdFJVwtxGAw9wfc4mCB8vvYaLTaoQVA2O7XYezRkyYIsGUlesWb5K84/JLMeV7+JYsFzKc5Xyzm0fc6ea5volkpeewcfO+lP'
				),
				_LetterImage(
					width: 52,
					height: 50,
					data: 'eJzl1FEOgDAIA1Duf+mpyRLn1hbQ8OP4xD6FLbG1f5Rl81flRcLYXXXGHvWCbGhsqWzeNZjsZIighua5mRIpg7/am9iQSXun3MC15q5nUFcT/z3rXHpW+PCLEcA1cHl1yBgYPWSaH4xOlBt51gKETeROlfDNnC8xCChD8v62nonlRxMX8M901gEsq/5I'
				),
				_LetterImage(
					width: 42,
					height: 43,
					data: 'eJzN0lEOgDAIA9De/9KYGKOu0EGWEe2f2xM21OyPAVB1BYk7X0hbkHOKd/ZILMqWouXmUrLTtC6fn60kuXxSc5Mct0aJEPJBzRWmbpNh0UomkctZb3kdcOIRRcmk+PZRneygmTRS7pqBFAORc1dvn6vmIooG6ZCd7a+nA8+8k6U='
				),
				_LetterImage(
					width: 46,
					height: 47,
					data: 'eJzV1csWgCAIBFD+/6epTQ+HEaGwY+yU22gsSnX9kr0SNKjlql9pfapHXNqq1PJKTw1PXaRMW+vxnNazH9fmnGF2sYYuaHjGZN3W5AQ82J8kbgW0zND+pb15YKqZuAVZ3f8I0bhueE4rSvLyTPdHZTpKd5lG2aaz7rr6i9/bsdwAivh4zg=='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzt0NsKwDAIA1D//6fdGIzSmWjWC+xheZRDtHX/Mxk7o8sSW4OFtS4ynJZmQUptRMY2Iq+hVkmSPcOpRB0DEl94H1JX5rNCku8ZkHh59/Rcgl9iMmIOgc4kwlTCo5fgndKXycdeXQq7X8gNld9e3nQ/OwB82EEG'
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJztlFEKwDAIQ73/pd3YYBQbo5YKYyyf9iXYUKr6602SUzU6Y5ABjg1itJG2sEtfJ9nkKdWjbQ+Uvsfp6DKNxXuwTpo6DUu0t/GzFXtRFRrPV2n3jnE07nYTDfsmNDBQGDkCGhsI7dxiG9369SzTGtM2tZPOrl2jG6M/vPZgMOMDBGhd9w=='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8bYEAArPJDVhEDGhgCitClh40idMEhoAi7Z4eWoqEF/mMFBBWMKhp5igCnVXez'
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8HYEACuNSMSIUMGGB4K8RUMrwVYgoPa4UMOHQOfYUjBvzHBYhSNKpwVCF1FQIA/wk8/A=='
				),
				_LetterImage(
					width: 37,
					height: 52,
					data: 'eJzl0ksKwCAMBNC5/6Wn3UjJVzEKFWcXeYQkSB4WvBkgGcKXGxFk5hF+hzTZiCwoIuVdpJuGjUpIPkoEs5i3qNcnQ/HJliEOo+7QcZm+rkMzQ4RnKyL340hEdhBN7ABOTketfAAVtzUE'
				),
				_LetterImage(
					width: 41,
					height: 56,
					data: 'eJzt0UsOgCAMBNDe/9I1bgzOR5SqCdHZtXmUUDLnT6w5p3owmvxwCAamCslNC1mVoFSvQjpkIE83F98FsQ0wiCnYTL0O7U7FYmpQrdrDo5eJcR2IDUISupSh/KvnoVw41LmLhZl9iEZCm0/DrV4AzIj8PA=='
				),
				_LetterImage(
					width: 51,
					height: 57,
					data: 'eJzt0lEOgCAMA1Duf+kZdR/OrBXHQBLpn9JnBiiy8ouUPQFS6bRTTDqQozOElCqiKy8JzL0aIO6GOxGaS9Uh7jfaCFwNEP+HcbpjCDz6T4lVWQTeDSfQ5RMyIyeUYUIGTSdwxHzTTCRAznezkocsMiexTp83qM/qag=='
				),
				_LetterImage(
					width: 55,
					height: 62,
					data: 'eJzt1OsOgCAIBWDe/6VtLWqT4hIBm4vzE/nUqXOMTudzYI+TgRVfXTAljx19pQyMDAc9jE8UAyfDeilTQs77xpiJAtiLcStj3uRjfy3jL2ZtRmkoY6n1w2NsEhM3rDHFikzAaUzYbxYrXo60OxkWV2B6mv2KzfYsbEy1TyI='
				),
				_LetterImage(
					width: 44,
					height: 57,
					data: 'eJzt09EKwCAIBVD//6cbTcaSeUWbyQbdp7QjSFBrOz8IEUXsGdtIa/GYfaTQcttv1cxbyArsdRIXSRYsl2e5scaqz1hopX9lDe9ZTsm8tQcUCz2wwKdYfSJiQ1v77P0vPbbXH7BWtl1rB87VAWjAGTw='
				),
				_LetterImage(
					width: 48,
					height: 62,
					data: 'eJzt1cESgCAIBFD+/6epAzWWLMGIlpN7ynzrpIdkXvltaE/Uk6N0ACqS6+u84mUi5EFGe4OO9OfjdS7Vw29N9/KmqwdnPIW/dRK83nH8T5SStbWwfyqp3uhAj0uJHrV6e7vQ4tlx/dULf83bWX4uX3ZkuAFarEsY'
				),
				_LetterImage(
					width: 51,
					height: 52,
					data: 'eJzt0lESgCAIBNC9/6Wtz4hdhEZtmtxP4aE1tPa/4EytG2kCk02KokvgM5wQ8ElC218nsj9Jcjtm6xVCnxlfMovQKjsEF4LYy/j9YBEfsZKEokrCGb5ITunsyzhZf0gyK3GvTyTyLw8jdl86pLFIQrs1ibOJbz8Ar3H4Tg=='
				),
				_LetterImage(
					width: 55,
					height: 56,
					data: 'eJzt0ssOgCAMRNH+/09jjBuivR0eqTGxs2w5BQKtVc6Y2TS4Mi+K7TF7i5mTJOaZPzMwCYzJDBv9ytvMG6MY7K42y2bQd8vURha3lxifHafGVx5lQi0wMQjaK8yt+yfrh/KKLQZ/Tk7+LOP3JtbuUewBFAMQMZliCayrHvj1EVI='
				),
			],
		},
	),
	"8": _Letter(
		adjustment: -3.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7////fwYs4D8UUFsOXR02taNyxMvhC2tayNHbf8NdDl9Y00IOAPtPfpA='
				),
				_LetterImage(
					width: 28,
					height: 44,
					data: 'eJztlEEOACEIA/n/p7sxMWEpRTlwlBM6BluIAoNhZjXRzHasVALnGjgLW4HRWZVzEc+lVrCfHuOK2c0gQ8VYb4PJ3tE6amGB1INLlKdi6Te/wfk130wWzV7+V5995vnlPgiA+qv5APUlXr4='
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzt1DESwCAIRFHuf2kz0Ubgg1tYaic8FZhMxpCXaepfmurkzNi+2mtaiCpJH69kjhHENzS1JQ7KzfqkTFMzIymcDnWqKV/nJRVhLJqb4B4jPKklyxuk0/BQOijMwN73Feq8pCIslZMpht1i+0miqgdJf9GQLxR1h2qTa/MBABAOHQ=='
				),
				_LetterImage(
					width: 33,
					height: 43,
					data: 'eJztlDsOwDAMQrn/pd3PEMUB7EjpWLaiVzfBqBGfCLdawDGvjSH78qwWyMzsSWYxmBFTW2C4BRB7AFrgsffjcYDZlAjjHIBeEUwfxC0yVAKY4zFfcoPXPgiA1qOA+PtQATB9UI8VQPFADE3xpLOJdOinxHOClQ8jgEh9uAAHGa9t'
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzNklEKgDAMQ3v/S09kH2L60oJCWf42nk2TudaQIqInoqbi0T6XyE3BxDCyRPbNBG6H0y1VJ4Ugnyi2s7XMULlgpTCuUlyK+hWUXsL2EgkycvhC/SdgDecmg3shbfkfxXa2lhnq1P8LKIr0vnCpuRTdsic2pWhC0kBLSH+sCwJDMfk='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8IGLCC/zAwQNKYarFrGJWmmzR2tagaBkiaMo+NStNAGrtaVA20kgYAX//oJg=='
				),
				_LetterImage(
					width: 31,
					height: 48,
					data: 'eJzFklEOwCAIQ7n/pVn2sQ1oS2IckS/xYaUE9wNhZi1U2J64z4p9JZIFXG4zhgc0QbGYkDbehDvYxjgAMoIB7A1OKivYNI43tTXomNYu41zbyiShk9sCyszjAB5Zh3+2peLqJSbEJ/gXP8ke2TrQEYrQ6AK2S/kj'
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzV1cEOwCAIA1D+/6dZohcZbe1Bs8zjeIKocZm3RvhyDF9qPYNRxi7bTjPZ9TvEOfqKMSvnyzV2Utazc2T4csRsGb5MeZF6mouy4d4Ha4z2LmqdkFOrRHYSWBNMVztJ5RoElcgZ+fJ3N9mX+d2dR7uhJHtg8Xz0wjIJk1MJc1MJVyj/gLXuAySCpoQ='
				),
				_LetterImage(
					width: 36,
					height: 47,
					data: 'eJzl1d0OgCAIhmHu/6bpd5nwUt+qeRKH+KjI2HQfHTaHYmq3LViLixO6UExgfZZdygDD0xXT8q/NvqIYU8yyIBjoGDZAMc7z89REF4ul0uld0X1gVlZtvt8JVxTTm1rDxn8zY4rxUXOY3qmYI0ldiazqnGHE19CMJZNLKX+A8zUTkrZO3A=='
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzN0ssKwDAIRFH//6ctdNGCc8e4KGlcyokvknl0RMQI3TFTj0QfJRIrV1Uqu1o6A5Qy0yaplVxcIJHtkW7I7rq7ZY6k1jcSJjG9eylp3EgWxd01iTGX8nBYXju4xegCf/5517q72W758U8+4M+j5JPUVFWBXSxqpZwhqacqqtypV/bmAp0Uz1s='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzFk8EOwCAIQ/v/P915kElbl5nsME7wRIESySNDEngCFI0IEIayJBAiF8tf7PbS2WSX62XOCL05yqCr3AsRfWpma1vEQKAW9JHy+OGNLBSS/6cPQ5/tWr+tXMbuiIFoyH6AZkxEXtcUwU0='
				),
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzNklEOgDAMQrn/pTEaa4GqyeKPfHUvXUvYyGVhgCQIgl16D6cGwADQEWxS1UVGcdtrjtT6I0lTTJuyqHYskp6rhjUAJEEQzeelUWZlPvh7Pp8eX+d7HEbYxC0d397O1abaAFZawU0='
				),
				_LetterImage(
					width: 43,
					height: 48,
					data: 'eJzl0rESwCAIA1D+/6dtB72KJCFD7zqUrfgKio7xVYTr7rDhpPKHWNHUjhKuwxQ6QPMap2WBUZCFtP175dneOdXD2FPN3Hyq+w/sFGUtXqDgiHCncQSfUwnXPbR1k+ZvTksLs75D5Ri895oOw25rXyXyD+9VUrpT/l7pOLDDlDU682LvackaxxHVYQrdovJyN7rVFu6o3cQF8mJB9w=='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJy1lFEOhTAIBLn/pfti9EXaHdhqIl8NHZcuEMf4OCJih3FU/OM4G+QmHQLYfMfU+jlSWqGhCqdTsuzHI6r104m/pNC1PqMRc673qGZAmGCXkSK3O1OhIRWmO0vhc5da3rsugdmeemGRkmH2FImbmZRYT21oOdfaHRIrO28WfclFikKsQgZsDzBECXJi9CNj0iIXhvkfLAvWVA=='
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJytlEESwCAIA/n/p2l7cQSSADPlJqwYAXXfm82o12aU5L6gHdNpTIMFguAVEWB0E676ZpSDumAdeBsSO0p1OzVlKwr2md67pWa5eKXP0sFs0XUI9FQYoCoA8kjAjEoO1R7iMFTSPymg1RWlU5U31VCbqWmheiYvNO1RxdJv4skCiKtTOE6hhJBKuuWnDg57ADLusXk='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8IGHCB/zAwCFRgUY9T16iK4aYCl3o0XTRXQQ2/jKoYqipwqUfTRXMVABGeNOg='
				),
				_LetterImage(
					width: 34,
					height: 53,
					data: 'eJzVlVEOwCAIQ7n/pdn2sw1aYMQZY/+Ap1hCoupayamqHhNy6wr6hICK8pvweU/gqSBidzYJ+uonimx/Ithk6GyWEpoT9rIuIYOEyYEXYjLga+V02Q6JTbawJoiL/4mpWzi6pzbnCfRnIuqeDCbs2SHAFd9CZj77TtLqAfE9fqw='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzVlsEOwCAIQ/n/n3bJ5gUs1EY5rLfZV3RsJI7RLtPoVxpNE9M3r2t0Io1GkcUsI3g9C+Qbd9LO3qPDP7FJm0Z/tkRbJ+2fN+jlzXtoEDigjU1apBNp9IzU9aRSIo0PC4uQRhe08+Ge6ZfXaHHSNBp1htCsJz+ZNI0GgZqOEbhuiyo6jdyicaKicYReMkBRdiUJR3gA7L58vA=='
				),
				_LetterImage(
					width: 40,
					height: 52,
					data: 'eJzF1dEOgCAIBVD+/6eptpYJ3CtGTh7xBItoqm4NOSPrqL3P5BVVF0bWWWry0Aa5kI77/OPa0dDpnHODgO46Szo/qKJTsntBkRXO2S9OyN6DudCHGS2WmHHhawJnMBqlpa4J+G5Zl9/7rJMF/4fu3/usc5a4zg7ckwdDc7Towv7ABZZfpqYSu3S7jgcIXAE4'
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzV1uEKgDAIBGDf/6UNgmDMO73aKvRn+4buxiD3TmVmMjxLhoNONuna5nIyUICxBZVwIAzZ+DPOD/tYC0E6ocsaz8vD6qdd1agR1XAsOsdmDRZIJjYXDDLPtyx5d32Xgk5Oi6Pp99LuaZrF1/rPl/bSu0QLWLOwwscAx45gMTnILg3SvP4mBAlbFHDQJTsAUY+tiw=='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzN01EOgCAMA9De/9I1Rp20qyToj3yxJ4JrkPw2kAy9huFeA6qokezWsxKsYtCpxRkZXim0b1uyQ6Wt4ZkczbdmOVds3p4lCh9q1c7jCk/S9mcyjnvP7Bc5I5lfmWhxZjeTiq0rS06Q7MqG7Tf1Vbx63wBzdDXn'
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzN1EEOwCAIBED+/2kakxJ3F7SYeKgnnVqKaHW/0axWUx9giQeYqS81Wq3gMWaes9Dh3ZMuBOGvx6DK6Ya+zmvFx5ycd1V3aK9W1XC2WrFaEmU7i9Jua3auguj/d0hDdDQd1lU3nWeNJ0ul4n7p4ufF41RwvlzyzHD3B2+Udac='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzV0zsOgDAMA1Df/9JGCErj2HyGLmRpeSI0cgW5sBDIDWbYS7txlksxmI2HF7t6poVdb2jDF+MXs8mPRWxOVrJaZihHSBI1RcCsEzTT57f1OsPRwX6UswRxbxoO884CC5+FUPor2DLlyElleq0NzFsy6g=='
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzl08sOgDAIRNH5/5/GpAbl0vGV6EpW9KSVQmPEByGLRqVZNaJ/w6oynFWV0VxBt8Wl2rSeovaqI+vdPVM51azZPTReV6EYhrCHszJZKnq6dcIor2FeKCv85oWofXJxlJrJ8S85V3O/busUJ4z+QtzPWAA1h3uh'
				),
				_LetterImage(
					width: 47,
					height: 53,
					data: 'eJzt00sOgCAMBNDe/9LoRqWfmaHRxJg4S/q00MAYH4x17J6OPbj6yM7oHpbTsYjXtOah/CTPNcKrAuDoHyVf3F7kaqh+MetbXO5lQMs52dpL3ASfS5aCLEjHWjVaycMC5blXo9Eib41H8+XXZH4c+BK4OtT/awI8lhgnM7nL6+WS446Z07MHTm3i3CJe04uLe+P43ITa1ERmA0nNEjU='
				),
				_LetterImage(
					width: 52,
					height: 58,
					data: 'eJzd1FsOhSAMBFD2v2mMiQZKp+1UIT74u3YOhcZrrf9YJZvfV16chqRZU9o6fvFA0FTeMWbeMiqxwMCya4ySaditWtG9Y2DQTBYYSCYY6mhVA3dkaEfjqG8wJTayOgJgQMQ1TL43bP6WUY8CA/smeyZMfuKcSX0PyjAr8PJ87b99xbgjQzsa13vA+JcBBhYnG65AtkdF/7jaBPdDJsxPNma+M8SLKozoF+V1Py67AeNSSQw='
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzNlNsKwDAIQ/3/n3ZQWKk1MZYymG+1h6jpxf2PYWZdrkHajLHQ2IJ3MITu24zMIoREtWqSWhDTtPGPSeWHKHNFEudQU7WonPKELHKw95Fi01uIcCqBNBTnJH0WLZKMmsq2/EOXDJHuOUc0CQmuiSRxGX3OFSrJpqYaEpP0MeWvAIty37HHolFbg4tybN8sOExm6kXxP07xDjaVYTwelp+Z'
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzN1dsOgzAMA9D8/093aBPqBdtxUEHLG82p26IiWvv/iqMK1NTR6/u0SweoAsX8IoQGWVTjVTdrlgH2Lc5yX6uItaMXfFPT9zq08rP3Vr5gXcPRms7OHr9HqmOuNgVdYmChVVfhanqmsl7m+K8X332o21o6m2t0Ex/QZHfeJUq4o/1sI2JobdLwO7R0kjGMx1wiXEoQJe0ejeTJ2e9NTHHpyWnzA0m8j7c='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJy1lUsSwCAIQ7n/pWmnG6skJE4tS3giPzHzfwmfvMUnFfzYY4j0FhIGIKEnWwuvBsoirU8mLNpnEjSNVsV1WdWSjH2SDFHnwCF9n53ulU/OI2FkPttOk/OrQoGTQzhwnywq0XSuCtygP0gYfQpSugQb4CS5O8UsH7wXzMtJ7ciuGRZW5bKGWZUR3JEljI5cU5EfHrr3An7vc8U='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzNllEOgDAIQ3v/S88Pjc7RDmp0ka+lvLIBMbG1hQF4NAwDjihwF5wabDqGBUvHLZ0aQm5m4PqXdBPrmrREtKR/BVfKVGgsoU+VtajLVGmvdqKqkSf0fuzunM4KNDwaw0fE3yadT+goeXQUE7rTxfzF2v9Di+5HmNC6NM94NG/nVVq2KMtUaNBEaVhnUsLRgNmKbToaElrdIOk4jML/h3jDBvICX+c='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8EGHCD/3AwBBVh1YNH66iiUUX4FOHWg6F1cCnCqmcohPiookGpCLceDK10UwQAEfWzaQ=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8MGPCC/wgwwhTi0onfgFGFowqHikL8OjENGNQKcekcTAE+qnBUIfkK8evENGAgFAIA59A09g=='
				),
				_LetterImage(
					width: 37,
					height: 58,
					data: 'eJzV08sSwBAMQNH8/09ru2mRmwfDjGYXDqmUUn4WckeCeEi+eLJJJDpi0SA9pRAtnUHBB8wgPmqV2h1LIypldfYUVELUbbkPyQrUjkILqDst8gUtiuYThQmFdzyFMHUQ/7shRKXGER5rGzroISx5Ld2oRtAYO632Fjuw+iiCc1p3HFviiXc/My6LfUvt'
				),
				_LetterImage(
					width: 41,
					height: 64,
					data: 'eJzV00sWgCAIQFH2v2k7zhQfyPGbzKIrIWZK74fkiKllUIrIj1NQKEJIQXo5A/lTDey3MwzNIVQJb6R7oNWg3iRu90Vonl0Fm9rDsMwfhCqP45FuhBAvXAmj7SJ0ptQkCTnQ+in2QavBMWjN5Ufw9HW9dK91nqDoIEiGV0da2QxpVP0DgsIeKgo78QFy1Rcw'
				),
				_LetterImage(
					width: 51,
					height: 57,
					data: 'eJzd1EsOwCAIBFDvf2m7UDcMIx+laTq7Co9Q07T3j6clyEiCeNjqaTLXCU2C6FCpW46WOLtJlGIRES1+Ij/ACGkJMjriBFJD5EkdwXusJqo6JtoVAERCkyALmoPjIzOE7k+G7S6XzDolooesrJC3fxcJMjriBOIg8sRJ8A3/QVRlEoSkAobO266wWm4TxgxCYTeIwubhlgg4nx9GvnvL'
				),
				_LetterImage(
					width: 55,
					height: 62,
					data: 'eJzl190OgCAIBWDf/6Xtop+VcI7IhFlxCXyk1VzV+qYoTraHkxnt1VVErMVYOBnAakcfkxqT85lWD2ZN1xgTb/ogK7nsaPIxGaFMpMLZI5/LAJ3Dri6QJoxFLjuxZbxrsJvh7cCJpsccxZo2uAGV/enASz4nRcrOtFv1SQaohSkY1qS719lIgpdixHYZxtbvfv0qxt8FsbgNyI9y4g=='
				),
				_LetterImage(
					width: 44,
					height: 57,
					data: 'eJzV00EOwCAIBED+/2mbxtRil1WheJCb7kA0tqWcWXKXx078E4uuJEvKY4FDNGgwdwn/bSFKtSpdsSVgl962Sx1Wdlm4QKJtm7ss+rCF+/UeLCmPle8nEJ7kteT21EKHMSFuVTx4RMAe6/s3PVY2/sdwqIltm6dZ9GPb+7l9IzLCakiy5DDU2vMLtdBR1wOreF1d79PMbA=='
				),
				_LetterImage(
					width: 48,
					height: 62,
					data: 'eJzd1ksOwCAIBFDuf2kbu1AqDIif2JalviHVWGNKPynKFfV+pgh61FEPK+qVjJy0Q2AcRhZ5ObnDc9Dr06AnbbfX+gyCnnZ7uaL1vg7v9lpmzhcB2nT84Wajpf7OeA1DzQY83kTDy5TaZ9JzYZ8OGYh6euV9sv3+kSvyfR3+utcynm9DXZ5NwkZ66KhHC7E8CCX2dkMlG/sv1OZDLiHIr5c='
				),
				_LetterImage(
					width: 51,
					height: 58,
					data: 'eJzlltsOgCAMQ/f/P40+GBNGW5gOxbjHtYddCMZS/he2R8xto4jVcSQzEWuj0P6AGRSTdp/tmJF2A5Edz0B6O/RZsPQkhI1AEDX1x5DmAIngmskImUxNMgmBmifkkyP3g83RCB0imowjeg8ZCMiKy4QIuP13PhcXEB+rIOu8/WcQr0kEaxTxgkSAuaoOddHrBARu/PwBHLSTan1zhYxYNwr3sJY='
				),
				_LetterImage(
					width: 55,
					height: 64,
					data: 'eJzt1NEKwCAIBVD//6cbI/Yger1lC2TrPlZnuQRbO7kjItOgZzMTnWf1fSZOmuYcuLcSgYrNs7gaxEj9Gxl/XLPudqQAww8Bmcnvmf0KYejymMGa4xJrMn/XKDIlYP8QyCT5pWkW/WiO0TeFjTgDb5mZfIeVHHjF5yTYDZjZYswDuhBwIq68GnP70RnwQOBrh4Big6cvsi3TgQ=='
				),
			],
		},
	),
	"A": _Letter(
		adjustment: 5.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8BGIDgPw5AbTkGJEBrOWQxdHlqy+GzfzjJ0RsMJr8PZTkALfO+UA=='
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzN00EKwCAQA8D8/9PppS0aE1cppc1NRpasIPnTAJhQZdZxZs9wRztBUhg6kzu6mzE01vc1M3RONv8GaZ+5Lb3DiikN/Qdz0HQqEm/F0bHP492/MvsHrrM1mU2TF80Rs5AHBz27YQ=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzV09EOgCAIhWHe/6VtY6uJHOGfV8Zd8gVCa4x/hBlTBqB1zLNEvaHzTHnGQpS9tPOHkNJKFGAq7TaCoCa3u62ofajWplsVRuhU+/GmDFJLMBVkqdRghdxWQG+TRmw6ti221auU/v+y+g5a5YdIpbhVFUvS8gFZZa97'
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzV0lEOgDAIA1Duf2nMjDgYZTX8qP0y2yNoo+rXIhSMdMF5Q8CVDpA1FIi/80ARSINdYOvsCAF41AFxS9HNMyAU+OoqkGvaAVRPhbYgvFqYI0NsN/0CWgMt6kVwP9dA1x8dgJxfgElKYOgAYxI29A=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzV1EkOgCAQRNG6/6XRhXFoPkUj0YRaGfOwhxhKWShKkD0ZM6As1ZVJJT0UUVGMKkGpVnQgKi4eP3U+w7jYbVQ8U1O1NlO1NKW4HKzjvWJTL9gqR3T8xoPpH0mU7s/w0VZXUO5euL21iopHxS3+rgxK3skbzM+weg=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8ZMADBf9xggKQZUAD9pFFEMZUMkDQOrzCgg5EqPZBgEAfLCJMGAHHjPd8='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzd00EOwCAIBMD9/6fpiVTZBTExpinHDkXAaPaTAFBrh5MceJxnvEEjgGLNCBzzZqYy9LN5ZwPrWv4hOSqwmKPLeoFrFivkHe4wKY+sWBv4rvZ4zi3LpIWq9k9t7QucvckGT4cEjj2YjCusVb6BIR5QPmnB'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd0eEKwCAIRlHf/6UdS6jEygs12Pb9Kw9lpvr/iHB5h8uEFkBlzYw8Ia0oPlmDM2tLX53K4Tlc6lpq9+uhgdUDRv1sydDAGelnRaRwWWpYhnDpdSabJtL0Acnv4+/g8+Fz53/0YumW52TbItL2sYz5iuxxKqu+AKC5eMA='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzV1OEKwCAIBGDf/6Udw8WONDuUwbp/1VebQqmeH2HMnZaxxb158qkRF8agsgGsxMbvbhkb4WRs4smymT7XMVjcxghjBFu/NlMYgywxQTVrVjXM+cyvMmUzHWT6/A+j7qaUjY43LDdRTjSvysxwF/Kw8jg='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzl1UsOwCAIBNC5/6VpmjSplQEH+0tTdpqHIC40+0tAU2uorihHHE08LYFOcg8eubRegkme5WXUiT9yX9A5pLntfl6Fy3hskzIbcE1GpS183hMydAeZqEYO1CYFVZMuUTxeqKBN4O43+qS0i6XvhEnes5Ph7V6VKSz8aAtDhnm/'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzN0kEKwCAMRNG5/6WnCBIz+ZTSTakr8wwmQe3vlyiaCVPWigyIQlSiSijZVgHFIabsHUUU5QCnQmv3lZyR2lAxwCGBWtBb4fHNHSxk0HiVZzHFlPZ34oofiCmLLvvp+xM='
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzN0sEOgDAIA9D+/0/XGCfQWr140N72MsIgI38RXCCJIfZI7SFwQQsqqw4zJXRhknrCKRwCFyTRUWgPTeLDdCOZJQ8HF5h0k8eL95ubZ1n3a6GJrJTrH4jwC6EJLRsd0Q0Q'
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt0zsOgDAMA1Df/9KFoT8ldmqpG8ITSK9JGkRrfy4DuA4mxaTHA51uteUJbOmvFl3T5NpgIbWp26chkp4iVDUga5rP4YCkubboz+7JrlRSDivaYiRN8o6K/kCg4koo47pFjw7jf+LDRZpamPUd6q6h3Kx0FT18WJ/m/XCaV84pa8GomCZTOXid79ODbK4b1HBvHvno/zk='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzdlFEOwCAIQ3v/S7ssc2azUGrifsaXKU8sRG3tNwHAgkzqxAoUPTxKYcCDSkhQ2BSTIyMLDq2k0BdJtyRGFG8Ni5GSUvFgQuu1CUnprjELIUQUC+JIoKRmJD3hzpWUnoWyO135uvUN4/eo5FV/YcyoJZ1e6tun9d241MYfbq1WkjwAoCRE9A=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzV0ksOwCAIBNC5/6WpjdFgGUbSmCZlJz7Bn9mfAjXVooS0uqcrChrBIaHaHFzIXjmbe4YvKMuMjGxmW9V7j0Si2DKRqykjz8RPXikVagnlklrhOaYdImJZrtwTSYX1h4RF1LPSNcU+G7m9Fb670oPqQKmZ2aieNKpMBd/GF+pAKX47qZujCx3JRPQ='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8FMIDAf3xgEKhgQAWDUwWaOBZlg0AFTu8xYIJRFUMVDJYQG1VBLRUALQGMkA=='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzd1FEOwCAIA9De/9LML+OkBeZmYtZPeQnCMs3+G7S8FKgLydCzKjCE3zkRICkJzMJbsgolcBf2XIimpHEm6PDTGPsEuYRb25IggK2CClUti6jsfVwN2yUDZQtJxfff5TihH51+poVvZyLHCQXELznmAh3SAzY='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzl0tEOgCAIBVD+/6dtjjYBCbkTX/K+FQdsWGu3hgjTPSf1mrMB9EjAMM11sqnTXixzPjjQH+Mw7V3p5KxWDZvaL1VrWc5ps5mk9v66Ms1lSM/BtG1JaNFxRL8t8TxoFHI8tjrsbjb1aie/1Po5ocXLrOYKpL3coVVDRo+OB2oiV+8='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzl0t0KwCAIBWDf/6UdWyxUxE4ag9q5Kvvon/nQEKHuyYeuDWOup+jIyWpHBmgn2uFEol50ravrVefU1zi7dOB4ztmHqLt7DHQ2qFN24Ly9lx3pM2aXQmzq7gKaddF5t3Wsv3fk3hLi3PzNSTpwHV/N46+J'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzl0lEOgDAIA1Duf2mM+jOwsDLnErV/msfsiKr/jvByzyNaZFATM9JmphaX89UE7Wnex4CrFqyjUaTjWujo5ilbJ617J8QdCzpbqtOeLtbR/YC2uakTa3UKje7LIc3BaJyGbCl6NaWNV/TS/+QbWlmNPoR1VAvo5BIv1T2sNDyyAdQNYOY='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzN0lEOwCAIA9De/9Ismm0F2kyzL/nzhRgpRhxYcAZIk9qslcEZqgE0sId2K0/O+MS3Sa2M1wzOsGEPtkl/WIokz19js5HUGGpQWJu/SdA9JAzKqreMW+hRi+V/+21xpIWzgRcJYXKq'
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzV0kEKwCAQQ9Hc/9IWWmy/JoXRnbPzIY7Gae3UUlaZK+tdBVXWXhCosA/aHesVxUO+jUnHKLx1VtX0ZU9gU5kW8srquZBNeX/xpJr+nRg4X2uel0G9267iY/3rXJ9xrSrqNJ0CGPgC2c3dPw=='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzV0ckKwDAIBND5/5+eQpe4jAYPhVJP4WVRI/mXAAqqLXNj53WoQc1ngsVzGyHMbMcXXNrNqTEzzAy1hdqvBScmffukse3uJwCxTLBp7K17YTuEKDHHW0axddiMM+PnRjHmOACEy4mT'
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzd0sEKgDAMA9D8/0/Hg6BJl9pdBLHHV9ZuYeTPCojY6dpo9RyCpAgKWwqpawa8RpWePaxRubWFICr9SdHqkpHlPSj2dQwJQat5YKK25Vn7Oe01qqZ/UV/8kjLofUKU22o7v6qslYw8AA+y+CQ='
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt08EOgDAIA1D+/6enHowbtB3oDibKTfOW0hlb++dVY1agx9S0ZTNO3meIY/d4v5JaauTdMZRheGAGscNqUOOj+E5oEuLdgz+kOMjgu8DyuOViTtto3sIoHvUKTncxC5zW9DZMxYYmKe5eSB6zFnJvc7xym5MPpeys6louf3THYxbncDXCWRPERfHnHDb5HJ/qVqAXz9l9NtrX+E4='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1FEOgDAIA1Duf+nph9FNaOncTEwcf2qfMEwsZdWPysx689ZprDIqPU3TjtsRc42YH+9umpWE1FAdz+R8SxGBb5ho6KSxqS+DNXITr56NBpYJj/+SISI1Lp+bkEw0ZDRz9dCwlXkA28r52qj507hbiQn7zjc+r5vujQufleeFHXzIJL8ub4K21IBRoSHHA4Ydb6Lxoy4zbCRSevOV0cFeG0+5SBs='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJztlNsOgDAMQvn/n56J2eINCtM9ytNCj3StyVr71QUgBifIHfU8hnLSoikJnElJg2iOZPgo+uTDTUiMk1wDsTnJAkQo8daQ4uos06NmH6i+Fb7bHCGZVbfHXZR8UO9IXgUbVaVU7a8F0z7c/cIfmpP66Yov+oywZJ4Zkm7KXlAzrnuNW7HRD6HTmbK+AR6CQAc='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1UsOgCAMBNDe/9L4iUEJ006HlJ3dmMCjDJhoa3+xsrM2adP1zVNrrJemOTcbdbxE0AZL13jJJ0Fih3c8q5+9r2eZhjOexn3c5nA01ql44wl5QE3zm7K4gTvFLsrThiWJMtEqjWgcsousztwhSQk4ez/ruo1Fgpfr6FMsBUeN6rWQJHH2Z2o6uPTH2as3/ipXewfkAHmqOhs='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzl1NEKgDAIBdD7/z+9RoTYdq9KCT20t9yZymSN8ZuFupyrDFN5kqpECuFhl5zb8CvtMLJYCkvJMvHqrGQmr5u3kJT8cBytSwvLNouStV9ISXLG0odTiT0iajHI40rCDT6VsFf3TN4C4hBvvC53rCex4DcD6pcjgSpj9LRa5bCfAZXrhoTfyr6UcnSBtc8Dt/Q7DA=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzl1d0OgCAIBWDe/6VtNsu/cwALL1rcJZ9Ac1ZKPw9Z0zn2aPHqEy3oKwzXY0tnIV1EaYEB4TCxpnFBNglu7tBlqroWplkFXPqxrgnHIE2Gv6JZO1h3GZcWsMTbYmx1nfWd3KNluh5oP9/Juq1pdvHIcU07tANQNKzgGXGfTjbmld/rZtWnS2bE7v+JNeNHdHhp7UuqbqjPB1InNh8='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8NMIAAuuAwUMSADoaAInQZrCqHoCLcPsYSJqOKqKtoyILBGJijigaPIgDjWyQH'
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8DMIABpviIV8iAAYa3QkxJHMqHh0IGHDpxBtiowkGtcGSCoRAzowqHtUIAIDPHYw=='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt1EsKwCAMBNDc/9LTrlTM5CcNtNDZKa8xpiDwR0XuPIKkhhwqM/1I1lgXDZHQZJFoRLxCrCgthNl3Hdnnjz2vyUPEB7cssacJsX626/Cms4gZOiEL2aCEfJFF6qNEUbdsPIh4mhnU94O/j9x3dOy6iJyrEGvuhcg2SBDgAhcn0Wc='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1FEKgDAMA9De/9IVv3Q06TJpYQzzp7xtbR26/+mK3amEtg4nfBEKBWjQxvAJaNBIWqAhCBcBiHcHBz9Pb94IcdnhLeuPQzpZMJgtIevE6TX5DAljoy6AqVmGc4QXSkirQoLSkNRvI8L+23Mq9FoYigAQVxshaesgmLH03zjmAvSz2G4='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt0eEKgDAIBGDf/6UX0QKdFufhRtDup94XMVvbKYkIQc6sIZjpvSRRqSZCkN4Rn3oSx1cDYgfQ1+0yQeKLBl1PrKohj9sPEVvByfjWGSJryNXIkygE8RAkms0lNywnxG8Qr0Tcg7h9DQFebJNXMk5AoscZ0pd5EufnxCqUKHcAh1Zr6Q=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt00EOwCAIBED//2mbGNqoSIVViAf3iDukjW3ON0cmpQSyklimdVQNZHVmdZBRq2cTu8ak7GHfiNdm7G87yLKS0XBUOIvJb+HN2paNsXswMun3OotRCWPjgGyA3VljY9iLNeuhxdBzLTOTBT+tnUx3AZcBjI3cWXNgZXSMMSmX7WIdtbCKPovcvqQ='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt0UkOwCAIBVDuf2mahsQBUAG1LurfCc8Z8aYRAI+lnLEk7DbncwtqdlkQhtlyMFqPLzNvqcBba6y65TErjty3GLDib5fZt+uwMh5b+7HNM3ZY4FcPW+8JrT7+D30+ZQfv8FNbFQw2FY22kWsVb7BpwgNktYe/'
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt0lEOgCAMA1Duf2mMSmSgg5WswY/1c7wuSMw5Qk9KqL+z3RdE9SKePilhe61g9M+kJUOvrnT3ZfI63OmVyzK8BFafF319jd/4E4D+I6jvSxQvWkR/dWYLoWXgRy57Ywv9HRz89D3D94Lt6xjwasL7+rZj87V1AN7iwZM='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt0ksOgCAMBNDe/9IYowvpf6BEY+hOmVcK2tquwiIwftZiQjRFkpK6+gghUffLOiLz4Xx9RiNC9uukdTCIN6axyfMxuHKIeJ30NXfeFYRfYkRk/kVin1slvGqIDxiJwozk4uMkHx4mahdsS+Rc0GXjHxMmNf/YJpNENHCJvqdFnDFV4p/sRyQhGhS+6gAN9Hjc'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1ksOgCAQA1Duf2lMjC5kOr8CigldEt9YlAW17iydkhdnXmHlTg8L616W68qw1lzM0wQDJNJ1DKuQSd4+gqdozCmtvey5ILt/xGLjnK0zrDUBBsifmfkJMRMZyTwkmA8GsajoZSlgzkoDojHD0j+COicUg2dys8WYnDKHaZ0NZm1VYWbnzQCLKXHFCuYAg5bPkw=='
				),
			],
		},
	),
	"D": _Letter(
		adjustment: 0,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYMAE/6EAixTV5NDV0UOO1n7CJodNflSOfDl0cVrK4eLTQo5abiYkBwC/OE7A'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzt01EKwCAMA9Dc/9JRBjpbExGGfi1flSdYWiSvBBZqLEhDD6Mjx8tjkCBuevlgxhctjza5ntBvm5ZJ7YHOcn3EUm+qxqm3wzn2IYe3+Hp2H4yx8NoMzaSQBXfCS9E='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzt0lEKgDAMA9De/9IKdeBqkjWCoB/mz/ZtddOIzUhkPNXJKPGUkqgYpApkrSt3rb6qJoc1dlQ6wVPwdZ9R5smzwxVCoZT71SdUPjlKZfQ9FfV/0qqJfuVm3TlmIY/23asGOS6XZ7kNwqmwAzIbq3E='
				),
				_LetterImage(
					width: 33,
					height: 42,
					data: 'eJzt0UsSgCAMA9Dc/9I4wChtCQ260I3ZER4MH6DkQY0EGYKJBNRgjgTe2I4KX70JBgnFfJePzw0Jak1ANAw8+uQf3AawX7QALH1OgiQSNLNbnnNq5+vYe2/nTX8ukuXiiMboABP5XMA='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt08EKwCAMA9D+/09n6MGVGtMKg3kwN8drscUBx8QsFy0FopT59KMUtCEXQ5kSXdFKXTOa15WybuWZymYOqrLA2pqv+lNxo94EUkXPUfGqDTV9nBUbSdzTdd+d5mvFbyX+TyBTiCmQxQ6VWolXKdHyAKJpHQ4='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYMAK/kMBdlk6S2MqprM0bscOCmnsakalB1AaQ2ZwSGOI0Ecau0NpKg0A5YmecA=='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzt0TEKQCEMA9De/9KR72JtmuAiOPxs8gLWCryWMPTFmeBYQakEx+LkUJYqh3FNPcM5y4p/5M7ckfv9+Qkm7f8bhulwmeuwO9NDBLc33eQydb/8rO5vGkaJs8QNLRYIDNVt2kI='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzt1MEOgCAMA9D+/09jxBgIa7dy8KCxJ2EPUIgAaF6wI+FpTPFlrlepNZNcKxn1WtI2Ft4oZ8x6QTEfz95ByfawJF8qN+WsSUmwlon95Vdlb7oyyabkPzOX/dGWddK7tx49Fiz0JZyNCUdH9H1WKtVsTM89B4TxM/c='
				),
				_LetterImage(
					width: 36,
					height: 46,
					data: 'eJzt1cEKwCAMA9D8/09vbANlaUxzm4flZn0qFkQARxdkpmUYSczagZMY4aQh9q5qxbV9zVSlIlogO/KNQWKuCWkK00ar32xp7lFvdHJTnr0yNol53GK1XRScMK5hHDefnPkD3BbFzeEJtGnjOQ=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt1dEKwCAIBVD//6cdtUFter13e4lBPsqx0oLc/x9mmmqhKSbtFmeCKbAyQkMaU11OJ1Fk3IkWjgO9lKTgksLS8tyesuDyrW25Zenq9+mSjKVAJpt8kjGdybzRmEoZlXBsyyVoJ5kIcuIvAGVU+D6YxGqSNepxAPfovmw='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 44,
					data: 'eJzVz0kOACEIRNF//0vTiUPAKl21G1nBk4AQGuCihhFGoIYRRr2oNPO027JJTt38l0l+9tuCS43WYZLFoPqMhM3cr5G5+t3IGItjpXbKB2qsaKY='
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzV0DsOwCAMBNG9/6UnH7mAMaJJFCnbAE8G2cAHSRqckhkylaXi81UmqKpIorD2dvOW/vxKprZ6o7+V2nt23pFh7ZtN7SMZ5918ABYkIMGCBOUAGf7BTQ=='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt0ksOgDAIBFDuf2nUpLUVmIGuaqKsjH2Q6Uf1cyVSddIp7ZBW7TN1l5Ex3DVIVMHs0E0NRTho5u7ENhZJDPqyMMnsB63MtudGc0+Uz6Z3/NP9VBk1S5D6BUSDZPso/uX3vti9cibvoxAuvB30Ir2LaegCipylxCm4bU4z12nBnXUA5i1X4Q=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1N0OgCAIBlDe/6WprVbp9wO1tuJOPAJ6YeYPIhpkjQYpWJyRQgZEx2wsCjIVHFKSDeu6GO8OLXMft26JBZ3CLCiaxWIs+6b6suVv34IiM1jELeVu7ZV/HN3SKDY7HOVkLqbQE6X/sQsTo8/Xkqj1zQGjJO00RBlyKLG5AEqAymA='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzNlEkOwCAMA/3/T1O1EhVZBlLRAz6awSSRSGtdUitIt0rQEpQqnIxqFIABSsHhZIKZA6KsvxUFlOesC31G7xvFLVIDmw+W81+3Mh2YNUX9SZ1V1gFz0PjdMEqjMsp/DqCCsrJW0GNhFGybficdjovhFRAfI26+1ucxHgzuBRPzWNI='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYMAB/sMALgUDpwKbhkGsAq//Bp8KXMpGVQx9FVgkB58KLGKDTwU2h9NPBQAjJ98v'
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzt0lEKwCAMA9De/9IZ86trkxYVhoPlT/JEiwJnx+r2Tt3uCHNBYsbS9UOYbsWWTVHdZ05UrB09CMZmhDrqF18QBKgfhFrk1TkizxcEmV4KceYrIo4h3/ABmldeE0hpai9o64TsgQtppVXV'
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzt1sEKgDAMA9D+/09XqPOwmcVkeBBZL0r7MkbxYESkXuHqKk9rkRjL0zSC9SzxlkaR25B6NPqF7gK4P/qgenafuc5vargtstwaE40TTFO/9da2PhuOprWi21PW9W5pqagWj7pu52rlrg2JGwafBEzk83+GcCpOdL0DdIXLXw=='
				),
				_LetterImage(
					width: 40,
					height: 50,
					data: 'eJzt1VEKgDAMA9Dc/9IVUbCuTczwa2h+ZPWtQzcYgHAC38GxuOI6aVHjuha/dSMd6hSW8kIu06aGjpJlYh1XNpS6/R1zlVLH4O8+5HA/S8qxzLnzabinuO6wvIk1dcI5n5d/mnJyS0Nfp7pTg/N4A4xib7s='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1eEKgCAMBOC9/0sbKEHI3e1WEhHeT/vmciG19stE2LDHl6t1TBlLjqQdOLzoyOHQfBenvK6tM0CdF53aa1EZKtCy5oFO32frrW9pYdPb0FyNNqAatntLowdYxxyhCXW0+ASf0vyIaFbCFn56yzSSUDOYTEvpFPYcCQh8vA=='
				),
				_LetterImage(
					width: 20,
					height: 48,
					data: 'eJzd00EKgDAMRNF//0tXkKIT5rsTF2bT5hFCGiisCtQaoRVBBKEVQWjd2cArCf3U9HbvqIz3TBcyVvd/w2zEg2GWWR5WEd3NdIrRTV61InZR/6lz9gNt97VZ'
				),
				_LetterImage(
					width: 22,
					height: 53,
					data: 'eJzt1DEOwCAIQNF//0vbqRXkS9KlXWRRXohEEoUhwUaNwRzMUe41O8pgfueZZ1X0v/TVNhwiyke6zLXM+2hVXJeQwlZTmlctis1di7eae4UHWSsny+/yXPICr9H9EQ=='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzd09sKwCAMA9D8/09nKnO0TcQXGWN9sR4iXkDyAwUYaoYizVIUs1R6dG1IZQgq40Bh2Kcp0eXuJWrv83+7Jzub/VFjNNOFBS+aeYpEVHHf4jFSjGoUY60LalYk+A=='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzt0EEKgDAMRNG5/6W/Fkmx6SjpQkFwVs1LoUnhG5EsNlW2puN99TjbVbeqMc6OSeYEXjTXdG7Y+UJTw27+66hRFbQXjygFtUf7wKt6tsLfg1HKCkYxSo4z2ACLOoGb'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt0lEOgCAMA9Dd/9JojMpgpUX0Qw37Iu7NAiGlWUNldsXaydWY7XWsO+jG3BjKMFwwo2Hd0DhX2HFNMy+/cB6m+4LKrP6TgB0y7g7Ph0ouM8T7mfyXPAleNxkHrec4ar2Dk1/AKyT8xgbJ3X6eExw4tYFz2+KYYt62kVNbc4Ud1zTzPrvWApzYJSI='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1ksOgCAMBNDe/9JoiCa1LZ1BIDGG7pR5jL+FpexZMyKy3kid+4DNX0ZbmK9Z0X0hldZca3T+SQcNI7Th8sqYc9AEe/Cdppa1I6bnuQRvC1JrmDr/8W2zzTxjt8DA12KwxMSrXzT5Tn4Jt78y6SWP3+U/TQoCkzeEBuYT08y3TAomGZT3hhHmx46cbnDOAWTdTQg='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzV1VEKgDAMA9De/9IVQdB1SRoY6OxnfbTLEM38c4WnzjJZT+NRSXWAct1Fo2dgsilLU9DSkOvHhiPvqP1JWchGoj6QpI+G4v63cpv1SegmB12OFEqyd9SUeJEv20uW67XEecAAxuahHL4h1Qd/oDT4dC0K2r8EQAmrkjOdFkv6/ADp1qGX'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzd1dsOgCAMA9D+/0/jCzGCXdcZvMQ9wkFcIaG1XxVQoDA19lqscaymloBWxXYOS553mIc1v6ytZqchV/cAwJZEmu+QazpT0+oi5W1SnfzKIu3x8PTf01bixVS+2Ca7PjPO7iHG8nW05Z3aOjQ+4+soEJqKoOTjEj+qk9dt4DKQOYQUl57AqhYPQq4lbVlkkRZkA+P7e8s='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzNlVEOgDAIQ7n/pTEx0TmghSmJ69/gWbIum6pDIlrUCiklWG7VyQwWozoJ4QAE9NSjqGlh0nYaLDtIx9o6TCqqviBpSHhTPcOXJo16NTt4IsTyX3LrDW2X0bkoWcqkr6S/xJAMZMlo7hM0RWaJ39jrQxCyc2NPWDSXwOkfL7dzsK8f+8gVJA=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzdldEKhTAMQ/v/P92LghfbZsk6Joh5EDQntRmC7jeZeUNd+lCHnQ1YUI9WgULTRIuG8DARbIlnl9LF3Dd6Hw34YrFjwcYiLdbmRRdpud2oTjwVE3ROyPJozrgOst5If7fkFMze9gAdMUcfGxxtSXvo6zpLI1Ua7xDg/FiMZr+Qf3yZponT9Cq5MQ2ctwSOAQGmBHJ+oBLPaQ=='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYMAN/sMAHjVDRhF2XUNGEQE/DwdFuJWOKhpVNOiTL1UUYRMd5IowABGepYkiACZbPt4='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYMAL/sMBfnUjQiEuvSNBIRHhNmwV4lU+qnBU4WBViEPJsFWIXXz4KsSuhIjgoq1CAG46pXc='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt0sEKACAIA1D//6cXdKqczahDRLuFL0wJeC+m6jUSbCNrAy+NJ0EqsjQKQXjvBBKPW0dzmdmaQ5SuorjpRx95xEz8fSEROV6KyMwOjUChqPuNqJ2NojF0t7S+g+CjRYd4vUMTAhTsPgcy'
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt01EKwDAIA9Dc/9IZ9K/WqAw72NZ8licVbcm/BOiEGKmYLog59Dhk7kHNBkRmwuJGmHe7G+a8OtcFSr4Xhp0eeGAfFCz8M+yFS+EXIWwE9C9JoFjASyBgT9TMfFZ8xM9Ba1zoIgOlmWHMyAvQy8hw'
				),
				_LetterImage(
					width: 51,
					height: 55,
					data: 'eJzt1rEOwCAIBND7/5+2SWsHU84D0hAHmBR8BBMHAWDEAmUEMYc1EsTDDKIgJZz9TWxo1BUi1SZU0dIH0Xa7ETzEvtJ5BDXkObEn1AmiUJMmx5OZChMVeTIXMXJvSog7FIm0fMfNEe/082DkNZnvj7Dh+x362lO2Zi/BHpyc'
				),
				_LetterImage(
					width: 55,
					height: 60,
					data: 'eJzt1NEKwCAIBVD//6fbQzWYqFezYhv5VHlPEEVERCVetJ3VGmQhzJnTigzj+cyyi5iCxQSGWv8wyBg1epacz6S+l5UPMvV+1rAWgky3mL3tzznssJ+ytjjEcOXYPQqzOt3KIoVZcOeeTbDAaXo2zVxYeOSmfbwcP3bkJcuWLzSXcdU='
				),
				_LetterImage(
					width: 44,
					height: 55,
					data: 'eJzt1cEKwDAIA9D8/09vjDFYa4wK9jDWHOurB5EWAI5ksNBmPd6p2MAbKzy1zo0ma7gpCUwqf7GDp6ezZk3c0X/NklVpsldVWDZoYQXedtsei3lltRWpW++t4jaTVfb2slW2QdUmByQ+BGOjbXn2wk/YkN4YDk4s5xIn'
				),
				_LetterImage(
					width: 48,
					height: 60,
					data: 'eJzt0kEOgCAMRNG5/6U1GlzUDgNtwESlK1PeJy4AgC0weMAjEMFM1Lcb73U0yFeroZ40/lAH9OzX3jaVvSv4VWnvD9/uwV7jWH8A6XmjvQyWX/7D/lwFvZykvz76fefM9qVp3Bi5JuO7/rmotG9F7CnSpuyq/h5p6Cu72gFzAdtd'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1dEKgDAIBVD//6ftYRHN6d3VimDMR3ePFiNS3YVLJBVulYx/RWSos8nGwTIYvhMpEiLdCBzGTikS/s18wsmL8MvSl+WSmXxMqOfbZJNlCQbMhzw0IfHnIBKs/oH4ZyGxB1MSxWmCL2sxYluFn45qgtjw+8SPByQOu2QW7wgTbnUAQ0xu2A=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1NEKwCAIBVD//6fbw4KxTL231RrD+6gcM4JKyQxF5B0mNbxYzUSnlgmBHEqzANyYwKCyYCYx6gljbjqdof5i1LFDz2mwWO9l4BWTJUtGI/Av0dU1zBrmM3OHrczozmeqBTDPEMzf/f9MFWPWTWlDg48xQ9jMA30Wi4aB4MwB1Jl52w=='
				),
			],
		},
	),
	"G": _Letter(
		adjustment: -1.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8CGNDAfyRAbTlsamklR0+7BloOPbxpLYfuhuEghy28aS2HK5xpIQcAUHPeMA=='
				),
				_LetterImage(
					width: 28,
					height: 42,
					data: 'eJzd08sOgCAMRNH5/5+um5pUmDtq4spuD9AHUPVhSGLxpg6EzRCChDypuLZA3u5yRXtdB5noxDEnIVxNayCc5qANaNq2ZvZpDeoJ7f3EHtwFjHyBksb7NPnp8Db8fxp7y4SDA0kIh5U='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt1MEOgCAMA9D+/0/jwcSwrq07mHhhR3jINpC1fgwAM4UksSsL7ymUsHu12EBVvER/hgeDahVXQEkbZVt1lFEayyOcqSatKrKPAV3KGsHSdoKlVu6ez8r/UjEctSP9b0nJ5MIOMxWPWCX3WhPo8bGNpCUcM6WgVE1aVWRUj7wA3pXbTw=='
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzl00EOwCAIBMD9/6dpYloqZRdiTHqRk9XRAFqz/wJAC2oDj3JRmAQmM0bvbDZkWwtiSfNaSI6fV1V4EiCMNL4F+LacX51IEiFEFdHwMkFC5A4fa3B/7gPRHvUwV4FP7YN8RWpPCRD+ct4dcECN5WiB0acnjQQPugBACl7M'
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzt1DsOwCAMA1Df/9LpQkv+ToXUqaw8cAIIkY8GAC7QK+wxIIXCW8KjmpIHXT2KGBmHHZ+iVoclTRRonLu0RHkRVSasqoRSHbkVMV5VC7bqotcU6WFyWr8yytBc2Q0bUzwMWUFKldXS+K3o/+WriSLkZlMXOXVrvw=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8KGDDAf2QwUNLYNdBceoCsHVrSmNE2aKQxXTxCpbFEG32lsbqV9tIAkMRPzQ=='
				),
				_LetterImage(
					width: 31,
					height: 46,
					data: 'eJzl1LsSgDAIRNH9/5/GwkdCgBvGxkI65ziwIY5mH5QkxIp1F1nCXUv60siH35xlz9i7E2vHNLhMBSwITWvWUogTRxqcW5NL9Rzf8/spuIzPW/kzNy+9vLmVzj+Qe4xpYMzF9FVr7mBp5XYAGXUjCA=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt1FEKgDAMA9Dc/9ITRHRdkq6i+xDM39rnRsXZ2gcDoC4x0Qgy00cXMcmxKsMQsaWx22SF7HtC7mseVkufX66W7gEl9fZOss5k5KqKMensrJ2U+gVJt6kur8oKSTiT0Yp6XXb1imw3pfozPZfzd8IfsZWME+m1klo7yTqTkU/lqTegRbOF'
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzt1EEOgCAMRNHe/9JoNEppfy2SLlw4KzM8CcXE1r4a2TNjMiY92XrIvNHufFQ9MHy3ypibGFfHeYJtk5v5zYwh6gxsiUbcd0OjnWtkTDiXYdHsgnlvzClmTOP/waqxLjJarZjeVRmpMneZmKMn4x0bZs6AQ2NYZLR7MpfbAN1GHhs='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzt1EEOgCAMRNHe/9I1MWoKLcPHaOLCbnnAUAjuny4zQ2gvprS0rphijIXTp3CmLgncglxJ+NSNtJIlxO3R0tDW6TGUMqtC1qiXQgU5UTckcEmKWUFOchyjoAOw7b98Q7Z8KLuFtRu+DT/3jFLlR2GCJL93DlepHKIe3ABM2iYT'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJy90jESwCAIRNF//0tvikQENqZwnFjhk0FFpYMDF2gZNOIeqQSVIOSxmATN5UEjIcKZHOcqIhe56A/BBRdccn/eg0qpQK35ufH2Udq1t2VxpdTQxZNDEbn0z5dI6iYjGV3jNw8O'
				),
				_LetterImage(
					width: 18,
					height: 45,
					data: 'eJzN0TEOwCAMQ1Hf/9K/A0IYG6llKxuPJEAC10sFKQqRQu7hPYOCescnOdYt8R17C8apyci3pFFxlZWtAhWoQPPaEFJI4edif2CFZRfWjCxs9tLCiBu2KQawjQweE1/ZNQ=='
				),
				_LetterImage(
					width: 43,
					height: 46,
					data: 'eJzt0sEOgDAIA1D+/6enFzMHbemMiRe58sYYbIyvIlx3hg0dGle4rpEPnIRvu7vUbtLWDX/eW3SzT0HDhDPVu0Stzigt+yP3xxr0SSHDdZO2LgLM2KP6gryYnjpj0Bv46QYtf5f8L3wOO9gNdpiy9muWPrN2jB2tzVyuLdxSW6QP36OGsg=='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJy11FEOwCAIA9De/9LuZy4wWqyJ8klepOKyMS4XAMesFGYZRCuDWMbK86mWTGahldoIZSon1co0CtlQFroqeu5SVR9VN/Rh+BdTBZUJOXQbrI7mSlyK7kJfna5Vb+z4SKlOjNwPFqgMxgawDvmCwlkxByN0LCevuv8jewAlUPU1'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1EsSgCAMA9De/9J1XKDTNglZoeyAZz/AmPn9iPBUaBgLSRhtWGjCe/5uETcDbFVdRKqdVy1s2z4r4oz6c0Jm5/15CrmakLTSltHrmEo+I/LlyKDKIG3RBJYSp8NyWmeBW/JUb4ChtEJ5seq6DLX2aELn78UgVB0yVKFSid8Sdc/sAk1jYtY='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8GGLCA/yhgEKjApQmb9gFTMQicMNxVMOADdFSBzYGjKkhUgaZ+sKvA5T06qgAA6IfIVA=='
				),
				_LetterImage(
					width: 34,
					height: 50,
					data: 'eJzt0zECwCAIA8D8/9O0k1YlAXRwKWtOBVvN7hbeinIu0EqnmyJYX9lfT8DSJhSIRXRIrsmMOGjyUKB3oRr0BZaK8q/w0i5YWhAKTMKz091RoQYKL+wXOyL/GwngfNbZ+mJ42ZVDl8n0+wKGjYwUSx9gSa19'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1UsOgDAIBFDuf+ma2IVCZ4aSkGiMLMubSupvjC+UmdX0WRnzOkkU9QQWSw8My7FFg7DYFHRS7doNesDbKbSsXz+veapDs6m4RpFEhwhejx7vw686212aRYReX/2avq29R4OA1jEAOzVNp+caPdnNGn6Thd46LfS/ERoFpJaRDs0SXKNIokNkR1+JA7t/oKY='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzt0tsOgCAMA9D9/0+jiRdYaXFxJMTEPul2RMSV8pnYnqiLWGuTdEYSdc6e122HUrVC1NXWa3fcdt9HnczvJjvhE45uQjmkA+csqRlmdC5Is469X7gCzai7Sqvc8Gy60hxXy6scnzn1OM6cdOZnCX8CWuWkTTi+WZ2oc/bB3XgDx8L2Qg=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzt1eEKgDAIBGDf/6UNgijnqWcYFOTffVs3t5Hql0pEaLgXDWsta81oBxuUTpBCo2t5as42dTvx8DFbPZr4MS1qdlguR3QDSagj6HQKja7lXc1ZoNOpV12HOgDXmsbR/Pr9ep2TaPeF0ia3PHn5gXZDSPJ7CfrE/tNAVgxRoGh8AwSP8Uc='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzN0lEKgDAMA9Dc/9KRgtK0zWQwEPez+uykZJJfLThDV4RhdEE1KjSMCqi6sPspUTvKDkoD5UQO34zO6Iw/MDjTnCUMZyXTVZWZrj80hm05P7hrcPY2Tn19Yti18rsp1htDLhokp9IgOZUGuwVeV46LkQ=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzN0+EKgCAMBOB7/5e+KNBuu4kNgvKXfSyZp5IfDHQU5rg0M8YQEYXUiQ5f6vgWD1VpAmoN9be5omvodauslX9T1JrSuNPraDqh9TSUa79pPd+TndvkjqJWb27fcoj7FUVHLft8y2cAxUvKTFb+QFmr96DuevIBm7wAKw=='
				),
				_LetterImage(
					width: 20,
					height: 50,
					data: 'eJzVkjEOwDAIA/3/T9MhSWVjS2HoUpZIB9gIUvVhICBnMAYYc4QJCkWzxsXuo45ZkAumvROLecGNbWmW23ZkCo6A4OSoRiaZ133AurXO/GPGKywulZey55xdWJarp++oMPi7DxWgUso='
				),
				_LetterImage(
					width: 22,
					height: 54,
					data: 'eJzd01EKwCAMA9Dc/9IZDBWTRnGD/cwvfWpbRckPGiIGBaoCx5oQa3wZcadut1Z8oDFV1sOyEFK1oWrbKQFGjqhzAdAWEclG+Kw2t1OP0w9fNBT3a5WLpyy3zrygv5CaYKWkm1VD0cM/dAGRqKlz'
				),
				_LetterImage(
					width: 47,
					height: 51,
					data: 'eJzt0ksOgCAMBNDe/9LVxAQROmUGZGFil/BCP9T9g2GKPUOxLLcSih1rwdomu/VpqQztSwpntcj1snNuAq4uKbvKc0vxYC9gLdaEJ1NpbReK7Toh+eOA58NMFWd6mOPsNEef+vOXuC9zuPV9aXhdkk6QRRz3E7YA7MXhdIM5wSTY3tNjaJMkBQfK2XzK'
				),
				_LetterImage(
					width: 52,
					height: 55,
					data: 'eJztlUESgCAMA/v/T+N4UGtNSwJycexRsiQtOLT2jTJVv5dOCIxdtY4x05ApPUPM6bmuBxjZwzGs3jEKMsJMRJPb7zLnKkv4dVYPGCl5zeALNcAU7dijkqg5ALeQ9KA9hQmf1jNMUs+w0zhEysSZa/Az32Pge1P9esC2BTsYooiYhk4YtMcbTDFOOMbqCPDsb37aux3suvpo1xNt2YiQxA=='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzN00sSgCAMA9De/9K4ArEmaVCZscv6oJ/B1v4YEeE6Q8YIk0n5hMnCZnunrNigDvSlW3x1nAXpdmk4LSM7Quc8HyfniUTvRabUpXGPtxJA0FWauBoJ9UElXQpoqFxfI1Qd3lZeyQ/Lbx/p4sVIcx6koERn+y84fcCM9cBYv9lwxcaozOkD3yPJbw=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzN1UEOwCAIBED//2naU3UDLGAw1qNMCWxMKvL/M95ToEk95snLXl3ouz1DIBedkJNncU1XBqlsKKU8pGLlaCCBhkqwIlToA1EVV9tPMrrEkrpSsk+b2NpTJUr10txNQGuWlzVdl2YvhepU865RuFaej3JbYyr4DV8TKualo+0OOxpXckazAwjkp+/83h4RBbWR'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd08EOgDAIA1D+/6cx8UC0tJSDidHdhDc2yMz87oqIvfQ4Cjocba0hwWfkkpWW1XlYQpjLNnloyU2FlnxR/vOawwb2MPaSWzxcXhszcVuT1Njtbw/bS9UAi+8ln/YgU0gaXR7OL+9/YjWS1pSG2JST+5obiRlXstLD4Q1PkmMhO9YQtZGp3uxk6/MAy6VS9A=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzd1FEOgDAIA1Duf2lMjIluhVLmfnSf2yvCluj+p2VmPS0F7MZCoqmD1cJh4Nx7AhaIy6kaDvZofEsYU7iwpPQXtWB7N7KqW5UvTUPvNG8q1lkAGmFvhWc2rkKzwAYNgQIH4/Mby+os6BmnH13Q03Y6Ph8+//lI2vFaKIZBt2u1EzgUSt+CN4KBQmeBTTpKUAyBUg8JSTs+2AFUAmLy'
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8OGLCC/6hgKCrCrRO7IYNA0eByzagiXIoY8IPBqwi7p0YV0VcRhp6hpQinjwdEEQDKmFDa'
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8JMOAA/9HBSFOIVz8us4auQvzhNapwmCtkIAyGjkKcfh1VOLQVYtE5chTiDbWBVggAB48NLA=='
				),
				_LetterImage(
					width: 37,
					height: 55,
					data: 'eJzt1VEKwCAMA9De/9JO9uNc07RBYQjr5/ogVopr7bCyXgXCkI1KwQoSQRCUHkRFMRiImxIqpG0erBDGj7wFWRmtrdd7eQACZEKw/0QxEBE3DkHv7pUgPqOAktv60RdIW2JqDPQ9j9D8Pqnxftj0j3B/IX2XCToXJTKJrw=='
				),
				_LetterImage(
					width: 41,
					height: 60,
					data: 'eJzt1cESgCAIBFD+/6dtOsXAwi6THWriaM8E1Frr/WFnaIpBc3EbWoxbUHuZuuTeSj1sjYPcqVDKzheyB847SNbd3hgB2gjSSuLxQzAZCLEKsEQOtuZRyF2C5aS8Sz3kTRpCoe0//AK0+RVjrDiyaFINwzD+1MiQpY36Jf1drzwalBKAzw4PwlTy'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1UEOgDAIBED+/+l6UBMEdqmUQ2PcY2FMqbGO8UdFRArkzESrJTmrkKtJfNIZQExrQMJnrBFYLRDT0kfUeO5EMcnyk68TZjsJ3iUlMZwg1sGSQwI+7+cuIuavulVCYDuxKHsJgOjVbUmoUuIZqBUIG4mSsTsB/zFOdPEFuVs4iVVGMthJMKMkhhPEulmi3AGtM8qK'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1FkOgCAMBFDuf+lqIhqhy5RVTJg/aF8TjEC0gxLOzGVXfO2MuWwti21BCmRW2tmz5C2WRJMrWdbVm8VN5auNYDibbUbq/7Ucs46KmIJ9jGGjJkl1ajPTrfDk92EWhkx8neeyZP8XTKEeJsjODNww59RCRp+wvDScJfVCdnchplLMMF6GWRYxBfsYwyXsRQ/R1yZL'
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt09EOgCAIBVD+/6ep1jJRuELyYKv7Fhwmc8n8kdCeiPV6EkmxpCZi5cD1IXoGj1rjzIjl9sIf27OgXJFhQX67tDVnpq2xEbAdx1YOqNVWU/cm4ZFHN8nqy6RY7en6bSmuYHuPrdTTtuq8zdbFsb1bXkupvzfw09baHiZi5YDDloENS7rqXA=='
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt1EEOgCAMRNHe/9JojArFzkCTEojanfR9oy5M6csj+4z24ohET6QXMF6Pok5/X+k1TOjtvL4EIf48sT5GmOfz+xd4Ek7y8HWoN5qmryJw/iiubZBHVayHT0a8/QcZ6vPxat5qWr5OJvlyt5pXx0N8sXT4AzAPGup5NMnj12+N11dRn8/VBhe2Jzw='
				),
				_LetterImage(
					width: 51,
					height: 55,
					data: 'eJzt1sEOgCAMA9D9/0+jF4m4bmvBeMFd6ZMxjLG1/crO0tLGEhtLjL9OQDjdYbWfKrxOuPiN8GCGSG1pg/VCJVRTTTzEB6RHREKPyr3kKcHpiCRpT6rwg3DxNcIDSKoHDIRrsof4yc0T5TJ/sjnxMidgMwpcBC9NErCK49oJ4zkqfxfwaxSFgwbjyAHkkR43'
				),
				_LetterImage(
					width: 55,
					height: 60,
					data: 'eJzt1sESgCAIBFD+/6dtmg46zi6wpHWRazxDMKfWTtxhZjJ4Qga7mYHYwRAIjAwgS2xmDcuKkUmmzOQKa60osgXzSldY6MV3rGfpTGmhkSgQyjwAWQxmlhX/MckwFi8zsWzFPU0axDumnpPDDtvKgI4YfGkSRZ9neDk7DD1nYlitwJRdO4NR//DIvcoBK9bLugASNio5'
				),
			],
		},
	),
	"H": _Letter(
		adjustment: 3.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ2Myg1+OXqDweT3UTni5QD7T36Q'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzt0zEKACAMQ9Hc/9LRRYSaPxY6mE1eDVLQxghhBwFM/Sa0cv/a262Sb5GEoLvzbABlDIGq8T0j9znR4l8752il2yGNlsgs9gJelHuh'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt0UEKwCAMRNG5/6VbiBC0avJxFaHZOT4NRukBJSumMinESqkuCZWnqbIdpPSrY/WFWzXIUDnMVJPbG9Bp0oi9jk2r6j9eqLpFqDxIlYVITVVVBUNayxdr5VPX'
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzt0cEKACAIA9D9/08XQWaRbleDPKU8iRrQeGGUBAwVBt6nwGYUjLEC+ICaGCCIKEMUYI/o2BNL6m75AvkNFbKoDNY5B7Ol4K4ngJMUGOrnbec1'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt1EEKACAIBED//2lDulRurpeiqD3GmImQaiLChYULokSOUK7AKXhtp6bNBear9QqbbvFBEqQqIlANF7Q1n+GCDb2mok+qOQ0Vaj4q/MTtKkDKhaUA309U1g=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR2MSo9KDw0wiENtVJpu0gCYYegm'
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzt1EEKwCAMRNG5/6VTd6Y6fsSCWHC2L5hIIBEUoSKrhGzM2ski7p5J7LpMslLd5W/cqYAqe1Na3USgkprQfPgz5mNW8gOOdX41abidIWy2sFd7llIe/ckt/Q=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0kEKwCAMRNG5/6UVKmhESL7SQlo6O8dHRFFSYdGOFNMy4dKnmaXtQtl7JK+9B6R+mUIu2JOzjuTQRDbtDcJD6Jn81vw1j2XaH/IJOS3vk6MisvVYrnmLtDiUXVejVQQ1'
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzt0eEKABAMBOB7/5cmwiR2EyVy/zbf0gDgWGAzlKHkBSMdzeQuM+Fgk8E3O03rRqZmiimOmMhGw3ySX2FZyfI68+b8n95jpFg2qWamlxuNKM1k5wGFWaSG'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0VsKwCAMRNHsf9ORioI1Dy+lUAvOryc4UVUYoRBKucLUWsqQfaQdc2RwwSSTKs+kTGNH/kuG7iYTNciFahIod5Ap0oPthd+Jyq3+/ch+9rK0TTzpdzYy3O5TmUJFqKYAvRUHMg=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzN00EOwCAIBdG5/6V/a8KidWSrssJHggkEMgdYZkN0TLBgeXMJ2wVLGSJEn0dRU256NF/HcmA+scRS6/5J7pDFlQx6APfj1zc='
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzN0kEKACAIRNF//0tPi4LiG7WLZudDBMXkGlxDAQo8FyRLYxcs/CIgwYIFyVz62LgdHte/3We8mCR6h7lc1ryWSKI0n2HpJQ=='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt1EsOwCAIRVH2v2nqoK1BfndobN/MeBRCjKo0Qt0IdYTKGww7Kt+iwbGQxhU8TZtZaNW3ZPkphgstnKG1m7R1N7XrnLoS8H5C6RjoZHd7A5vR5q81W4RGJSKadONp2nid82kjlbqHAjdyAVAOl6E='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJztlFEKgDAMQ3P/S09BFNolXZgT/bB/ax9p2o21JgO6dCF7GMgQw0LK6yjFYFDknCmmnSkpHrIexaeW1IqWd4w9ugtKocvqhBZDDkJ1jOpw1oZUPWVhN1J6Yy9c0v9gLa3S6ZGNPr/0l85rieIGaBX9LQ=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzd0uEKgDAIBOB7/5c2RjRqnjcZuaD7l/tKsZldASwRtKTQFFaosobjS5F6FGJ0L2qFJcWHLWy4MNaOhqD/wyPRAC451Y7EHqhnA+TU6MS2nGLog/vwq2vaKxN1FuUeePgYO9QLn+LbCV1/OgBa1Psv'
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAAROMqhhVMfAqBgsYLOExqmLkqQAATANG1g=='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzt1DEOwDAIA0D//9M0Q4YUYludyoBXnyBSJCJM4IATWNGtFGgrss2iTjvFfR9qRvwvLgC6/SJYu4Wqq9etXGef60TDnxtBRGjxHpZFXRck7QQD5CCfeQDeH7J4'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt0uEKABAMBOB7/5emUEziTpSwf7bvpgSA4wuqDqVpLgKJX6tNl9F5wuo4ljS+vlU3An1dR5brIkHqFOnvk1Yp12tPN6/HkZ3/5OuztD0TumiyOk4k3ao3tAkwOic8woLJbw=='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzt0tEKwCAIheHz/i+90UVOKeZPBBvYuUs/IkxJF4m4E7F6Ut75WuKsQVzrQafjfusG++KC3eQME6e4cytX0Gftnh39jq/24LgF546Z6yXipqnmPE2c4RsKFjz8'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt0sEKgFAIRFH//6cNHi0qRr3SphfO+ogj6N6IdTDXtsIl0nbNL7SalTrc9NR5L4szenRt7zqFL3QtT81gNI4hLdU6luuv/snofbRTrRZpHdUSOjliU11hx3DlACl/zWs='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzN0kEKwDAIBdG5/6V/W0go6BSyq+58iAYNpAVqHaErgoMNM8zuRIx5htlWBKlRZmz8rHh7mflDcmo/73SdvljM1m86sIy0mD14ARHWTNA='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzV00EKgDAMBdG5/6VV0Er7nVaXJqvkEUpJCGwSTNQYzMG8up7pU3E9KlWKKq7NU3Htp3XVjb/o7EXh1WeTl/rDXYTmHd5NrsOJv2oX1TQGMPAOI5ibgQ=='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzV0kEKwCAMRNF//0tPN7ZVvwVxU83yTSAhJFkuLMiwsaUhq7uLIYODDGTIQNYTuSMnso8xrQ12HtmGNy1PIXuaX8uc5XeLLH1dzDZkuA=='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzd0DsOwCAMBNG5/6U3FQSsiYSSBuLyWSt/ko+FGaKIwrE6NLtOkaaIwv8URBGt1l+3pq25mHhco6re5rrR119oRO/EoFnWaeaumlpmyQUQCbVn'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt1MEOwCAIA1D+/6eZl82oUNqYXTZ71GcQNborMUlL3FoUy3J7oliG2+E6jxYnPKsVcbC1heNODOTwtzjCM8d25KXtnKE3nwYgX2sJhUiuHI9y8tqtinz3zXyI1x/sOMnycGsJzzqJOGh8n4ed/I6X2gXaOWdbLging8M='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1UsKwCAMBNDc/9KpqxLMxxlroYVkWeZpogVV6RKe8EZGsXnGiClegEbafMMkS6Sm2DY2daverMeTstr8ztQgMEswGSRvDZq/jfv0gonWIDplT4M+cfZaN/6dHROSNkcM9hxNAcYkraamGC8x1XgHjW+1zWMDEWXzxuBg1AV/bLmb'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzNlVEOgDAIQ3v/S08/jGZCS8NiHJ/0rcA25xgqINUGiTNMDA6LD0i/ujB9JxgZl6YkKdInaedB8Mkn5ZPJfpidrpD0iHdrlJBI8jKlTBEjJROO17pliyynn4WCNHe0In++JKy8Ivf6mOJzwEwb75PvaZLVlJfAZtzuD7TsSfUDjszuSg=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1UsOgDAIBFDuf+lqogtbhs8gTVzIEl6kpJKOEYREoKrljLy8gsL9mjtJWQOuUo7GKaStdkD7/dbSTv1Iclp5VPmO9n4faszydcZaYCVKzqWXWklHQ4vnXEVWmzPl2rZo44ZAcqzh6tS+cbq6y5z+d5nTxEkSs98lNfjWp5rTnU9107cdcgDl1M54'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd1VkOgCAMBNC5/6VLjAmLdEoJSxP7Z+cJiBhFSgHirBkJF0auUHlhcqVBZdsyYdPeKLEghcjRkH3/qAydfEKS06DBOrCHrDOffFJDsrvYE/plj+3dXJI6DD6b/q/y7jLZKkebqQYn5NsWJr8BhX/5O9FXZ9h8mQBtautN'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzV1UsOgCAMBNDe/9I1GiNIf9PYAHYnfUMQJDJ3RcSJyuqzMhYNzNEAzumyZSt5V4+DEX43EE2Ttf3+wNRaZ0NtbwiyI5V6DMhhEuVN/VU/XVhfwNVO1l5bTmuBQi0CAVYPcp/7+/vbbm9IeI4VuhvF9N0Z8aJ/3DJdPrXzSfiB9nwAuGLNeQ=='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYVTSqaFTRUAaDMTBHFY0qolgRAAwFx1U='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwqnBU4ajC4adwWIGhEOCjCkcVDjuFAB7vSuA='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt1cEKwCAMA9D8/093u+xi0yWCQyfm2mdbRDBCB4YZhXBHAoXwD5R9QqxpP6rWA8lB+yBmoOrdqAYPehfskKqrwc76BtK36aDJr+CgL1BI1LTMiMxNiC23IKqN9WHHBf9Hi60='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1jEKADEIRFHvf2l3mxQho/mQLCzi1E8YwUJ3FoPuNrQ3xBiAVh6qqROoe8wwKWw6DRtuYcBmGKJPYWoG3CM9iBBrgSDdncG/XE/DStDvwqWEgLrtCoO1CsGM8d/LH3K9Xug='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt0tsKwCAMA9D8/0+7hzlop2DijQ2bx9RTRASApAXbCDQHnw7CmOOI71lihqvJfUInRYIEkUhVNUkJ1xHLBPLA5mJ9pXyZjscdJRycQ77xk4P8lrwbkthaIXmok3oOJ16xxLgLBpjRdQ=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt08EOwCAIA1D+/6e3w1yioAntnOHQHq2PcMHM7MJjx9kTkkHYs6QTo5mrDrCuRln7xLEYMbFqbEEzbIKrssGC7MWZ8dRgaq/PDLJ7WBZPWbXDERMLLDz9zoYCZa3m2Cpiu5ijCOvoDcli82E='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt0lEKwCAMA9Dc/9Ib/nSrTknVgrD0M30V0QLARRYSLevxLtmedSlhrZVhSzdgIfsz2/qx9X6vfSZYi3q9p0+K3DLrbSPftmQP30nZ7dYFhLWQtJ2S/fCEtYEbqqEBRg=='
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt0jEOgDAMBMH7/6dB0BgjkLMQI4pz6cxGKSJJCxh94AUipbHv93nf4+OU+A1AL3v7ef6qqfw5+oU/VMDvTXUhugw++rEfrF76sqH/zd6e+bzp8bEG/nbs5/rcjPmoVkN/D0Y='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt0ssOgCAMRNH+/0/XRN2IZegNGBPSWc8pT3caw+J7YmdYO0/skY1JPKJD1KpLyPBsJlOkyA9Eg4aMyvMkV79JviymoDLaJL8GRvhjYrLmjxUpMkNeAySJ1+wRsc2Q6JNtRBLCUfnKAcCe3Go='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt0lEKwDAIA1Dvf2n3URiM1qih26Ak/y/EUncmRqnPmI0QpMPsGbGURT27GV69YJVjLYmY2MksQxPLwb+sKm7WArCrDYjFDKNelGC7/qSY2KFsbnmHRZsBQ6cGDG4WW7Ca8jYYuQA44v5W'
				),
			],
		},
	),
	"J": _Letter(
		adjustment: 7,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8BGNDAfxrLIcuji4/KjcphUzfc5JD52MKE2nIA2+VNzw=='
				),
				_LetterImage(
					width: 28,
					height: 44,
					data: 'eJzt0EEOABAQQ9He/9KI1ZR+C7HUlcmTEW0NI4QRhGwSmASEYPTOih++9u3brQmtnN38XrV1Rx2S0dtoaf+cpbRjydZD6sq2YYcBvDJLByr+Lf0='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzt1MEKQCEIRNH5/5+uTUHU1aZ4m+C5lKNpUKW8EZKnZED18NRGSqaUJz12qrKrmbp4ajv9r24U61VRX1azjJUeVPyak9IvFU3BpS2PavlBWIEMFBwdKFwlh0OiAgyuGh8='
				),
				_LetterImage(
					width: 33,
					height: 42,
					data: 'eJzt0FEOwCAIA1Duf+kummUbo6zE/Whi/9AnBIHZYhK0SPBl7I4WRTTUpQ4gAfjXqSU2oIC4Nwi9CPBoQXDVOTiP/oMwk74xCVzgIoE3vQjgYdhdsvQBydCPmw=='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzt1DEOwDAIA0D//9NUmVqMwemOt6ADogyJuAi8OPFiVPjGC428uBrzT4VXeaJWvHfVqlX5+9GKC1WpNlaobW9VdBUlZ4OLo5rviXzqFDrTqOCMi5g6oZ6n5AGUvmTU'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8ZMKCD/4NGGkUJptSo9Kj0gEljqh2VxhDBlKKlNAAju9BM'
				),
				_LetterImage(
					width: 31,
					height: 48,
					data: 'eJzt0DkOwCAMRNF//0s7aZC8DkJKkYLp0DNg20wFqZJ5o2xkGBmXE4v6PeuuN0Ndvvx3RrE/ZE61J1x/aq4WnvtUnIs9Q3mLNnWMZllrX4OlJ1qzuPKYB8Pc208='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzt1EEKwCAMRNHc/9IpLbgQ5+sUFKR2durTRBdmfj8RvrzjS0dHnTd2nvbpYpm+fMa25PxyG4lblNQFSLa8K+MwWc2NZMr3nyV1T3RAWQEpfiGSmqOUfaCE+3XSygsPM/k/'
				),
				_LetterImage(
					width: 36,
					height: 46,
					data: 'eJzt0lELABAMBOD9/z99UsrG2KW9iHtzvmQC3B9hTA1jAiYqFOLd+Vn5BozB6umJ0b/JN66dzcxcM7hHTG+2ppVZRlXBJYUxNrBhzOgWf8swf9u6vixuZkD4'
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzt0EEOgEAMAkD+/+kaPRhXwJJ42qQc7WCbrQqDFIYSZzLVSSzJlIOZEi7f28iK5PvXTvIRI0eO3EUikfxJSV3+IQFVfgxUVUizZBl8nnMP2sOvAVSVJbzzsijdTuEDpd+EcwDx21Pz'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 44,
					data: 'eJy90isSADAIA9G9/6VT1R9rMC3yCRgySf4PFhEikLUIqiHqSyza/FKwYJl2Ck8klljSEyzr6vnRnQ97IqoJqgilezPkAbJF+BY='
				),
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzt0jEOACAIBMH9/6exEuHQqJ2FNMCQoAVm20B7KEABtD8ACtxK3fzlNem1i89SHqOQV4IKIullD1MJP9UrZnL5JtAApDcs8A=='
				),
				_LetterImage(
					width: 43,
					height: 48,
					data: 'eJzt1bEOwCAIBFD+/6dtF02A47g0Dh24UZ8ILq6lxlT3RnUKtRMZcvnBUWg+qiM0y1s0HChprl2ONXTo0P9RsAsprgJodVteKrtqKG4fNgpoNXuk5JHcVvOYMNlhCt2m2pfnhiEu1G7yACP0fMo='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzt1MEOgCAMA9D+/0+jicYA7bYmGPUgx/HoBgdaCxfirYvsyyAVA0oFlMggI1pVblgv47A+0FM5u1N9f7D/Ld4Y7LmWqNVQ1GouyjCqyX50VA7FDQyVXfDcATh5VkiQUEQOZv3OydDMZH0DuGK7fQ=='
				),
				_LetterImage(
					width: 38,
					height: 42,
					data: 'eJzd1FEOgDAIA1Duf2n0CxVo1yVuifJZnxBJxP1LZZo6S0JjaFeJjDfUoCnM5tV4oLMdz33hdvWXgfWVXuXe3cCSwVarVLuHFwdGSvcQOW/l6XhQFTFS9niAWqUfGakWdiodLeXOYHGHJT0AyWpvyQ=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8FMGCC/4NTBZoybLKjKkZVjFwV2NSPqqBMBZoQNg10UQEA5yVL3w=='
				),
				_LetterImage(
					width: 34,
					height: 53,
					data: 'eJzt1TEOgDAMA0D//9MGMeEmtSVATPGW5hK1U8kQJJAEzviuE4ATuCfMdwJpAf4R8aVZcMSIEZ8IBCFVEcWr6DZq/ULYe3tRB0QA68By2IKHgpLrYNstizZthq/oAPWCmp4='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzt1UEOgCAMAMH+/9MlHkiEtis14EHoEWaVhBhVdx2RnL5mpR5NpJusf1NgkuNf6ec7sA/NaZqjf62h83X0KtBOMlfL0XZ1QN92VurohHDLdXOW9v4doIOEtFcofl99gs4UzVoBhbjpXQ=='
				),
				_LetterImage(
					width: 40,
					height: 50,
					data: 'eJzt1NEKABAMBdD9/09PSDG7uWpJcp9snS0PovpoRFhXEu2WVIbwcg/TS8+7emZcLkkH893dDg04zl0O3GS/41zXWrnWjnbuZeB4+yjinInasG6yip/7YKEwuK8TlTVBBg=='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJztz0EKADEIA8D8/9MulIW2GDFCvZmjDqk1KwQVrGus6FLQuCPDpFrXldquG7Y2Wbsnnmly/ujRo0d3aqiaDLmOKogGeMW54gUPdHjcvcq+slfKx9cKcKNIu5i1aCP5x4KkTyTw0Cn7AMScaOw='
				),
				_LetterImage(
					width: 20,
					height: 48,
					data: 'eJzN0lEKgDAMBNG5/6VXEdGEjlgExdKP8tLCkib54cKMUREEUcVc3tTXmPHcYnab+kurfhpmhzbjXasDUOqzlnnDbDu2/knWcwJan82KDr+RbnumdS9Od3uh'
				),
				_LetterImage(
					width: 22,
					height: 53,
					data: 'eJzV0kEKgDAMRNG5/6VHEbUZ/cUulGIhEF6ySEjtvz6xilzIEjnrzj3vdItV36hZR/aYpFF5VLE2Tz18ksZstYXVr6hYtzz05NTywwbUrNV948t92zprLH9a7S8='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzt0zEOACEIBdG5/6WxE3SMMZvtlEreL8CCiM+FBRk2ZJwQyPjblqs8u8F6k5bx9CjpzuosW4bdkA3rUipkw390ZLA8z5ipAYEzwlo='
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzt1EEOABEQBdG6/6XNYsRoXREis2OlH+Kz6FIOB2aIIgpZMXQ1BFH+0q24V68u61d12u1os3AuKaLhWtO4XAtEx6gTHZ5q9obJfwLePazRPERSMPo='
				),
				_LetterImage(
					width: 47,
					height: 53,
					data: 'eJzt0FEKwCAMA9De/9JuMBhSk9TIYD/NpzxtzRhOwtIWjzuO3eXxxrG1PrUVjhSDao70vzzfEhwN4Rzu1Lx58+Yuh4Bw9hbiYi44VDt+zWlb+JuQ8wZXLutOXNqFa8s4plNbW/bh8xBplyFlLu89p60='
				),
				_LetterImage(
					width: 52,
					height: 58,
					data: 'eJzt1sEOwCAIA1D+/6fdjkZosdlMPJSj9gnh5BhyhU50E2+pecXEVLrYbaOaOA0ilZpvTU0uMtlyU/ejBsxoY2NjY/PJgAw05E1g6BD1MR/6mCHb7F5ab+mSK0NBYcisyLT5nw3MT0b6O6676vK53172AX9wHFU='
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzd1TEOgDAMA0D//9OFBSFTx7gIFImM4XDaMDCGK9inDyT2ChkCCyQSiFzILvAluRJK2oZScC5vaa88bS4/2dPC+J5F/fDb916pZTwyye1Kzu0qNJaiW5xSBBTXUaNCWa+IKDC9qSSXy3TqoOkvy99DJ8vaAB9IvIo='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzl0uEKgDAIBOB7/5deQQzSdHqy0SJ/zm/ujFoLChGoapyVl1cRNNQgLKPBDMZCzQ5XV2ZqnYfTGb5Sl4Nz+vU1N8rykz/rs2tuFCWhb51I646vrY473Gy4Oaoa+tBb0B6e0sPPJzhEjTVCPEVbsnN5x5XPF2Lauds8ALV53nY='
				),
				_LetterImage(
					width: 42,
					height: 46,
					data: 'eJzl1EsOgDAIBNC5/6XRXaUdpmONn0SW8IQWjRG/CfhyDxvC0jjECTpt7GPY1JZYlN7wmLyyhR29Kj89/LljsucqOQ7hw0lWtLxfFitSLaf7uCpbXmVyRV+81fR5+DQhkWuiZf8LErLAXHaYf7UMS5XwmN8AMhJo3g=='
				),
				_LetterImage(
					width: 46,
					height: 50,
					data: 'eJzllFEKgDAMQ3v/S1cUVOiStkGHDPvn8l6JwnT/+ZhG7zOHtms0uiWYiYJrgrZfou0J3S5yPHXpggs9FqVXKvJFbWwnNBBYEXhOa0s0Pp9H84+NgsY7vk/Dm83hO+2sPuOq3Rh3aItpulqjx19vTlOB0VFgdwoLBRgMlGyTqGPx'
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8NMGAB6GqGriJ0ldgVjCoaVTSqaFAowq5nVNEAK8IQxK6LrooAdornQw=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJz7/x8DMGAFmOpGqEJM5TgVjSocVTiqcFQhjRUy4NI5qnDYKcQijEvrgCkEAIIczWs='
				),
				_LetterImage(
					width: 37,
					height: 58,
					data: 'eJzt0FEKwCAMA9Dc/9LdQBDapcaJwhjNn/IaqWY6mDC7EO5IIBAwRnCRJQnCRA2+iIJcR/HNQoUK/QdBI38k6DkTEC/mLYeRWFYiMpUvy1EM/ba3yHza1QCQvlT0vjQXg4J9yQ=='
				),
				_LetterImage(
					width: 41,
					height: 64,
					data: 'eJzt0FEKwCAMA9Dc/9LdPmuMLtAJGzSf9aWoEV5gurch7jgGjxApdYgx3rYVBMfb9U048SqcL9CwYcOGf4LjoA55oKBsMoRqpgNZrEB9lXNQVhkCPFGQs/rXwzAo6g1s5OIdSos3uQAwVbSg'
				),
				_LetterImage(
					width: 51,
					height: 55,
					data: 'eJzt1TsOwCAMA9Dc/9KpGCq1EGPqpp8hHgmPCIHAvZISM4G0vEMuQesjIe4EgpjSipgvyNIBR8sLhKRIkftkriHBXdNJCB8iVoSRvrBIjsXfErxLcpv2ejaJf+A5wZCQmDl7I0bI5gbsPLoBKuMkPw=='
				),
				_LetterImage(
					width: 55,
					height: 60,
					data: 'eJzt1VsKACEIBVD3v2kHhiCmfCVch8D7qZ4kCGLuYENEtexNLTvEJCQvAzTJdJvd6bs/GdeyUcwxP82a3cHcI3Rm7gcxBUPZ5pph2daJs0/7CmZe3HuycwTDtL8dxCzsMs2OsskEHJiX7FJ+AOa8hOw='
				),
				_LetterImage(
					width: 44,
					height: 55,
					data: 'eJzt0OEKgDAIBGDf/6WNWASmHh64CPL+6T5lm+okiQhjV3bZCpdHOI0GGMvfhdn9gl1F1Z41YVHG/tCCqdAmvsUGA2MbrGkW7H3wBZs8AywJvqjJuqgPY72/Oom1HiA3YRoHbr9a+g=='
				),
				_LetterImage(
					width: 48,
					height: 60,
					data: 'eJztz1EKwCAMA9De/9IOUdjUphpmoR/Nn+0LaikZOiLevsXbn3ZkDt/YtFiPWvSrwvh+9PR1Qno76dNf9mYVeHjfTa+V0ofz4/jMv7toHn7M8J+tn1/z1+9Kqtc6fQb9XLLh2hpHD9rBidk='
				),
				_LetterImage(
					width: 51,
					height: 58,
					data: 'eJzt0MEOgDAIA9D+/09j4sE5LI5mEi9whL6BmqkFWdQTnKWlswSupHBiiUjkBfUnDWLlhNz3OZnua9KkSZMm+wQKoe2QxC9RAtD2Yxq+8yt5+0A3zfyT2zRz7TX1rRUhZVZLfHgQSnk82LYOTyQTPQAx2bWt'
				),
				_LetterImage(
					width: 55,
					height: 64,
					data: 'eJztzzESwCAIBED+/2lSpMgIHCIDTgquFJdT5kwopa4xepMgcUYyTUyBWNk5y/TYLck/dTM+ZlZtE1OvHTZs2LBhw0qZGjQxMMDM3WczknEYXFbO3KeXsc2xwSLblrk63DMz8sM/Ywp8DHggcG0ILCx4+wF0KFIt'
				),
			],
		},
	),
	"K": _Letter(
		adjustment: -2,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ3QUg6ZT2s5etpNShgMRTl6h+dA2T8QYYwuT005AEUTvlA='
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzN00kOwCAMA0D//9Muxyw2iyrU5oaGkEWCtAELIywYw9rOanVDIcST7iMXjlb7jQdlbk5r6v1Z7Wx0Vveztr58lPjA2uwqd8/CrOj7rbkTy/fe9XZnj2Ielyts54/+yRTRC/kAX7u7YQ=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1FEKwCAMA9De/9IbtDBclsZAP2Z/hvWBUXERl1GR5amdDIsdpZaOVE93q3KGqxwFLZ6WqvrwxSAn3htXnxjYw4GXc67e92Mc3f9qGWnVvbyJQtiq7lSxIxULJ1bw1PY9YnOicNFWwRa0Ujun4arZK/139hQLd4gqdgMOIK97'
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzN1OEKgCAMBOB7/5deWMg4vNvIQNovvb7MFgZEXRjVggr9GOTcgpmVYMQCUAwNVD3XzPIJlqgFwQEP2x1tg/k2FVA9PQBy7IE8BDuAjQaqUWGWMPd8B+W5eLlvAfgpGlBLPQBNFVhiAfwPrgUhP/5xcIsLd4JC6A=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1FEOgCAMA9De/9Izxh/oug6JifBjsjxHQSRiYaAX9+hFo4B3qp/PRooiN4SZFRdyJJWRlV4uV4ySvcFFq3xO9DmzGjeqUEFjR8npZqWDn6aqXTUNdxTtH6pTqBtKxSc6vfY8huIXa/rn4ynKSjesVXvhuf/PzHuoMmjxur4A8v+weg=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR0MCmkUETpKYygeFNKYXhiVZhgEMYYhMriksQcmHaUxlNBCGgBYoCL6'
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzN00ESwCAIA8D8/9O2RyEhih5abs4yqBkdwxWsWsZbzmrGFp/sKxikCEs6FcL6iHNv6i642slzbo5MszQXt6SoG5wGd5gD+Ig5NT2iwXMKSK9lwbzVmtNhUB7WJEHMPSHLW1a3NBMki0+0yxzqL1mr+ldzPfUZXsw='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzN1eEOgCAIBOB7/5e2zVaw4AAdW/rP6ytBVwEYtYEViZqGGnUZ05OlzlL55iU5rzXIOQUbtFVf2gacuxQZfhxEUpRNP4ZK72ltUnahVdKT/VvqeSr5t6JBGtwjgzMyWSYlr8ixKHWWSrhvx540BUTS7EAqsS6dZWhbTx7J/OdWl7y04+RNL0H+bso='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzd090OgCAIBeDz/i9ty9nf8Qgkrba4EvxWkAageIGYcRn2+IM5KpbZqp5ZN6ZNzSBCDiINNylNX4yY7lm0tttDYATPXE4rZ+SpvGpOmWla/pQhljH6O3PBMKLxnHH+ZSpOG3rdyFDjlsEN03JtxMZ4OEdZpugr96WpaAEBlvU1'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzV1VEOgCAMA9Dd/9IzJGrQtVudP8Cne7CKqO7iMBWK0sbQVC1tGrLUWpcRLwmuk97FZBQRp/4h5x2DEk0FkjR5FNI4d6EMfhaq4Ei6S9Lfoy9J675kt724TJ5RunBfhhNi8MzrkuTJZXjjwORYoW0am7LAqcA+SLpyJvl3qSdjBiJB2k1kCj/87w70VHHH'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzF00EOgCAMRNF//0vXxGiczjSKbuyKPBooFCgPSHEj6DchhSYcBxDR2DNCLC6JKXy9lGpSUUU714pUivbtnZCiFZ4Du/nPQkrfo5GUK+22yTt5fLhD0rDS+CtWZAMFR/sT'
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzN0kEKwCAMRNG5/6WnUKgTfhSlK7PSl2CiaG9D3EsN1KDL5pQDaedWEBp9iwpiZiWiaCaYIrOdS72RRvyUOmHKRBFFkWQGsPZ9a0rrajTOuKaY4qksvtVtYogRDwJHDRA='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt1EEOgCAMRFHuf2lkYUylf8okwk6W5DG0Jdq7u5rrxnKdQ9uzbGjLfVUeolt6byg5xKkS9lFyTUBD9S3vrqjqPVM5JElT75Jm+YWKOhNVvWcKgztAiyfIdd+mpk92OFHTUDjkYDjdt7onyi6zgTrZ8xCLAy8asuEEviVXAzQMX3yxKXzOljRk//QkXcjqx4PUcGNdvUULPA=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy1lEkWgDAIQ7n/pdGNvrYZCg7spJ8E7JApI/TSjZxRQLZYtKj3TRkqVohQY1K0vuQohUmttFJ0njoVvIZRcm+oFjgmUIgwyx1lzkJAeLEe9bWl+bFWsE+NexH8KKIyFbs+prrglBIEA0uNCczy8Z9R4lZcc8iyWXBLZUnLd/o7VXxye5YVLbF4ABJXRvI='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy11FsOhSAMBNDuf9MYYjRlOgMTBb68zelLb2jtORHNONGPhZbwhDrWEJOUGgIa5WBV/RmjRcVwWO1ARUuhoIqVweycohUvI5Gh0sxaIZCldimG8ucxSr0/dirixpnVArCZp8RopQdT9VWylkqJP6BOm2ZOG/IFPHUH6UroKFpexp4yL3a84P6oL2Ndi7BC9g=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAARMMPhWoYoNUBRYNg08FNl+NqsCnghqhTkcVWMQGswpc0TFIVWBRRksVADATeaM='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzd1MEOgDAIA1D+/6fR05KuhW66i3Kcb9BgNNNUOOBE3NU/bUUsCzPEhtwVIUDgAYccZxQaBXma8ELUqazgC5MQLStRbmdRJNSmoAko1Ga+INTWq0bHBax4JMJLKrMT8+DosvU7eiIUw7dxRjBLUYeE/ParPj8SFdA/BKgLOTL1NQ=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzd1t0OgCAIBWDe/6Vp05xicjxM20ou4dPwb0tElA+J6hQxzQ2RED9Wmyyja4XVuQx0TogfixpGYbOOrX6A4dfcFrzm+pw5oEXt9LBZN5tJanBp/qtNgtHaPa4v6MGIiYYnP8gS2uve1/q+NllG18I23ZY53a01phVdi6aKp0BrLZWJpv4GYlrRAzlJ3/wCNhpT8w=='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzl1dsKgDAMA9D8/09Phqhbu7RBhxfsm8lxwwkKoCgD3UGxOOb3rs0StxeKqx1zpsMEx2YDxrl7yEIujZxfsxdX3WDHOa5WopPO/YWuu0wc/ZDc5SwNHHtvLkrcnj/l2ixx2THIzm4duHLGNZS4rgjdqCMu+wGqrrin+axb5QI+OcN1'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzlldsOgCAMQ/n/n56Jl+igZZ2iMdoXIz1uKxo0S6hkYJ0us3RSostRKVoeQ5n4JA0dVrk2wCLOx0ID2m0noXGBATQdzltRlN1Sgm+WEAXTZvfQ1uoiTadoab4bn6a7bz7q8Chdry33kKb9QhqcELDEenVGPtJg+mWfHXsG0J0OQ+neiexo1ILScKBf0BHMfuREE5wgTfk='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzN00EOgCAMRNF//0vXhUEdZogNbuyqPAiFFKAsiOYIrgT8sZGMyTiHahL3IjWLh4VZ24NK5rXcRhOnE21YJZMHsWN0Te5xZdbLj2bvQKtUwHGrR961ejNDVtjacfGju3YAs9RkuA=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzV1EEKwDAIRNG5/6XtoiSo/YIWsogreYgkIkoGoUKJJXKJ/HZ9068qq9ZcoqZwhS2F8IoF2Iq1+RjD7+SZTdQmGvfwt2qi6cc7hS05qLB9LvfTShwmsNO+uqi1ugHdHvV5AS0v1EQfUZHSSg=='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzV0kEKwDAIRNF//0tPFwWjDobQdlNX4U2ICpEeFy6Y4cZgB68d2tSBDWGDxKlQM9jZCsMYLM9E3eoDq6umemVlj3QVN9xIlkJZuMyb3dbZZw0rnL6C3OSmweSm/5rM1OsCOlp6og=='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzd0EsSgDAIA9Dc/9JxIyPB4BQ/G1nRV6ZAyYcBZzAKo8BQl16d6GACxcgyHqkUnhW4pXq9H9CqDg4d60XVz0KOz7RsnMvhFEbjpmaxUqum70XrZkxTnnflutKoNFWlU/5fWcMZuQHi4usx'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt1FEKgDAMA9De/9JzHyodTdJWmCDYT3lbujodo1PW0i1uszq2yu2uju3pViMlvJfvm0nKjWi2FeIiFjxULabclsoCMecjQVzMT3ExE8CBfp3TYwIeoxQHne3k+q2Cg1wu5T4D3A+VcXK4HUkh0XniQ+7OU1nVG1r8tPWilfsMuIzcEtYa4v628P9MTIkZgqNp/fwLPNX6B8p4zc46AMbG/Eo='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1UEWwBAMBFD3v7RaCplJplQ3ssSXCK+tVY6iE92UFup6xZQudKGTbF1LJg1OmRNNzphxOFzvTFEBJiEhJdNRz0Q77TB4J2gIiM0MQuOSXw07v2fctNz4pR4xM/3AmBK9l8XSGZsyXamAwJ0AELKvmP6UQofedHW8PfWB2eMBCx8lKXWjMS1h31GYTzIm3TXXyCT81xCTBy0eosZFHg=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJy1ldsOgCAMQ/f/Pz1NvCSDthYQnkh3bLdMY6Y6IasTZJzHxMJhY5j8r0lJRg9Cssh8mlZdJpGMHSmJpxkk76JYYyXVwoknSE9AIgzHG6TKniPV4Az1yV3xek1fxpNkWW/L+yR6SUgPVb4uVaJk50ziQQ8kPl/nXif9L5H8432GUw83zhaZtucA2fdioTtI//83E+960voB0rlABw=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzNllEKwCAMQ73/pd1ANmhMU1t0zC8xzzR2gus9GC0CqnS7xzo5RgpO0Ykka+heGgUV2gqqH/O6S3PBc95Gewes0I8uvznQqnvKO5eE0tO190lmnqDlEYEOGuLjJ+njwekebu5V+JC2V4fsAa+gAghjhouClhVY0e10s/F8JWpAlVZP2NufwALlMzQ8HyHNaq3i/6FzvxjlKBlvgVxHizgd'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzF01ESgCAIBFDuf2maaSpDdnErK/6kJ0KWewszF+OKNAnbEb/KDw4HCSpjqoQh/Uyui5QH0mKk9LZMkpVMiklcLj2KvVSSVaugKM9jTJIZFSVnSwzDpYsl2+oNia0su4GL8ftXo8s9VUgfSHQv+Hgue5sl2jvaPzqbDvWG9Pz70/ZB0P4LO5b1Nw2kAnV5u80FN+pGAQ=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN1VESgCAIBFDvf2mamj6UdhcYmUb/lCcRZZlNYwwrjKq+R8VmN/yjE7im28oG+6X2ixFeA1g/MxBp0MMNEHjnQPPUAFJNSwCp3OZWLWrQOK/XPgQaOV7HMZph90blU0/zczTxnz7Ivny7VtOqi+jCTRoVwtsitTqROsMawetxHXNoQxu/f9py8DnSz5/j5J+/pi06GA06i2t6r+wLpkI6Gw=='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYDorQRIeEImy6hoMibNKjimipCIfAUFGETXSYKcJQOrQUYVNJD0UAMgPwLA=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwqhBdfLgrxK51+CrErmRU4RBSiCk0chRiVz4yFGIJlBGjEIdy+ioEAEfOdrQ='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzd1dEOgCAIhWHe/6Wpmy6UHw+WthV3bR8IuJm7DiuYVcjOkEAhm0H6tKF4gEJObKj9NMPJJIo5HeLCXOU+EnNIBFkBUekBGqytjryNbSiurEM0/CcR3l1ebxtqr+CSs4jPr6LYJzVBwyxHSL2PhQi3TfE+yh7jtNqvUW5q/9kD3TS7fQ=='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1tEOgCAIBVD+/6epp+bggjdRayse6YBorqXKhZBuNpQzGCMElHWQG7GnytBXBgOS0CakCZfLoKDK5gEsrEA8yjoISwHEa6QQnMIOqCaGIVzWQXwwX4Phpcj6vgialF4c1OO+LEQT8bC/S+qVlWDI7Y15FmLuYdB3Bow/zUPQLf/DBGbsxh/QAaC9o6M='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzl00EOwCAIBED+/+n2UNMAWXFpxJjKEXas0SoicuVKlhHJObH1gTDmOGL7LFHDavIkYtJaPlRBRvVmAemsYJb3BH852lF/BnZkXu8c0t3RRkTfUYb4+jOxLZao9rYEuhoy+sfggCR6mCD44KqI7bNEzaYTG+GJP4U1xLOI+CFDYIJ5VDASK5Yodipp5gadCWXv'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1ksOgCAMBNDe/9K4EA2U/qYGNIauTKfPVHEhEVHBi5azs5IMwpwF3WZpxqIFrIlRVodcVpvD3ETm1zN2X7HUZ9KcuoK9m7m60O8W/wST75Q4FpjVqRQbajOf8SbA2v6fmWxjzP+UlWg663KQlVcYixDWpB9j/RTGhheaZAO1mXoIcaauod1awCEG/Y8nWTEecTOQXe4AWg6hwQ=='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt1tsKgCAQBND9/582JNK2vY20lkT7OHMysYiIiAo4NNGins7zW8uyFLCtmmFr61hR51lnDiOscqG5npL7Vlv7inKsdnPoYKbY2g5Y+EGub3kQW+dz+IIVPM8674MMY9urFSxLAase0A0rtuHb8ohl3rS8iqza2hb5xxixjX/T7noDmciVsQ=='
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt1ksOgDAIBNC5/6VrNDFCpcio1E/Kysw8oqkuBIBCDDp4EEtQM3y+13mO31rGz8D1hrjdu3PSrxdV5fhWxXr7Hjv4pG88eIZfAOmZV/57XyUhL8Kve2Pn0LvfmxWneFG+zes85mEfdW8vQdSXa17vOF60rN9i3zeA54O/hawv1jENb6xMXSLIjA=='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzlllEOgDAIQ7n/pTExfihrO4hbtmR8Uh5lOKPu1bAyMR+xO2rVecQ+UUdqU+WqfyJEFB6NBtN6VTWEd4KIGUw3Ku0zDlHTBjVzwJea3QnZShlxn4zE6rWIOAZEoOfRSO+OJcyWIW36SYxD1LwZBL7PvBOQya6WPYKN7i5ABAkRbbYL0vmKBQSbKYTMdzaSIPjPFo8L/95r6Q=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1UEOwCAIBED+/2l7sJdSdkGzNTaRoziCxKatzYRNqWXMekyQEWbPWMqqqg0DBYNpWkvHQAKPkM42ZuaDMHiYnNHWZSxZDljlNJ8vNsGZv/Bu7CXkjPYXM1D9MA3Ln3Kt6H9ZsH7vhYx3UWXx9wrPm2fRDjhCN7LqqJUs154Vi27DmAYsK/oly//dGoaa5Qze8TARq6k2DHpcfkKexA=='
				),
			],
		},
	),
	"M": _Letter(
		adjustment: 0,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ3QQg4mj02cVnL0BDB34AoXWsjRM/5G5YamHAASH07A'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzt00EKwCAQQ9Hc/9KxCkNpmw9FKnRhdjNPRRy0MUI4ggCm9aZAquoBo3c9WyG9S1Z7p4zgXT68zzlPWj9l8KZpftt+YfGvVR3tdrZDFlois9gNaElL0Q=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt0VEKwCAMA9Dc/9KOVRjB1SZ+KWP50vaBxQLNCCKeUhIW26pGSFdg6qggVRRzFYexlSkRT2VzLMd7yZt7WRVcrYVavanV3bdUtaZffV7RpVRPQaooWuqVU1XxSbm8APn4FBc='
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzt0sEKACAIA9D9/08XHWqETokuFe2k8ogogRIHLSmI0FFgNmwAl7ANQZs4wI4t0EnBTtKz0/stAAEn4Ak+cQj8P/zgFTBqDQrXRAKbKwCJBB1VG7CvbQ=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt1EsKwCAQA9Dc/9JThAoapkm6KV2YpfMYv1gVBF6MeGEU8AuFRzMVtwWl3y6rve3WW9NUOYSAvE80b7Y6pWZJqKUUKXW0d8lcpnhfRx1FSn1Sy6hU3eSs+iV+rgQqL0Yuyy8VFg=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR0MpDRcDXYZ2ksPTgAPLDyBSlPpwZlaRqVHpRkYAACMsF4='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzt1EsKwCAMBNC5/6WjixLMNBkaBBfF2ekTPxg1U4FUyZhRVjNOMlKFN9/0MK3S4TiuZp9ig4V9j5hFnE7yUiBd9t4NLu8lr5bL/2J+6A0OixDzHizNEc6VvyXOALO97S8='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0dEKgCAQRNH5/58u2KBWt9xbKRQ4TzoeUFlJC4vuSDEtFy7b9EMyYF/UsrS+QtLqDtJW8fRc5uHy4lnPwi8d8ZVqgiNkw/rxIGkGy2T4U075QhbbfvKoiNx6LGP+Ij1O5a5Xgqa0dg=='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzt0sEOABAMA9D+/08TEiZs63CS6EXKO0g2AIkFMUMZel40s5MGWEo6M+Xq2NRzflmNm4i5TvQjTG0a0+4bXQ1jYsbYrG++0YyUa5OGBXWMlheNKM80lwEiJFnR'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0tEKgCAMheHz/i+9KCLMLfcjo7rwXLpvMmVmMKIQSu1hKpdq8h/Zt0mBDNr63M6KpG9D0k8OJIBiajbwdjxtLq9qlWyrWCb/f1bBmgx3fsklX5dWLP0kkYxndvLxdZ/KITSEjmx6pLdz'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzd00EKACAIRNG5/6UnggL1B7VoEc3yKYKIco1EqSbQVRElWhJRlERjgSA1lF3dmHIspsTGuVMW/y6mmDLOncRvyOJLOjUnp7dX'
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzl0jsOwDAIBNG9/6UnTeLPYMlKkTTeAoknaBCwTdwnBVLgC0kkGSSSZ7DJXbpMs7MY1imLvBaQsBQsnCdI/CD9SIz5W5CgXD+myUU='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt1MEKwCAMA9D8/093XjoyrE2EXSbLSejTFhQj3MB1I65zKO7YUFF8hgIexRQu9hJcciitc0NJaU19Clr3sWCevRn39L2J36NZVpTKgs5XrGj/EpiKR/PT06j4ax8lh1YtKrqYZqbLwfucT4UM1yU13MgF/N9P6Q=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzdlFEOgDAIQ7n/pafRucDWdmiWaOwf3aMQPlYKlfGnhuxKIFPMFlK5iTTMIBQpX5tX36kpZ1QTYaOnwy4zQVkvRI1S1HhX3H6PAiNrIalWISoa85FHAXtROHYhxW8hw1ZSLyyGR1Lql7dIZMlNTzfu+aW/9HkWedwActjLXw=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzNkkEOwCAIBPn/p2k8lEYYijVqupdGMrurpKq3RHRA0jQEleAOamVhx3mTCHHBRFR2fobt622BwvAwrKGgOYoN9OSBKApLqY7OCmnzzuSbmUqm3yhFamPhK3W88Kd74GvNRdmkoNT+u3QPLL7GCWpBFG8n5ex0ATF3yGI='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAARMMFhUIZbgkB5WKIQEQ3sAbL4NFxSBIhaMqRlUMlAoAGjrtIQ=='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzt1FEKwDAIA9Dc/9KujILYLMqQQj+aT31UCqJZEVSgEhjJu6nAsQICwAtf3SloHkTeVlP4qK5Iuz9TP7bxQ7OuhNf3i2wF1BZecUVL8L0KIj62Ch5nIscJBfggUx5znWfD'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt0sEOgCAMA9D+/09rsplodZE2yAXpCcZrwmEANj1wdcTTWgUWn0MXBRo99L1AM1Xnw4vOYwW+0VI8HQ1LSz8YqY1Ch24WxUUicJBBOpil27u19NJzab4L+jJUdb5Yuso/NBUUfTZ2RB1tyw=='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzt0ksSABEMBNC+/6VNWTBBIu2zUEXvkjwsBEBgAt6Bsfhzm2usrFFHuYN1sWs5dbbmvLBuV9jnRhwjp1znRO0sWHz/Rmfv5nPPHe5E6bnUYpya25ykjsv4AytY6kA='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt08EOgDAIA9D+/09jsosSqrQaDxp6XB4Bsi3CCBysa6zoUtI45he61gJUs9qafNppVvuOTvNYWsTQ5aN4bZzxvWV7vYNWJ2Dp/kbvae3dlr8zevRorkPVrBHXZ2MRfbHER3WHQ4YrG++qcMg='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzt0jEKwEAIRNF//0sbwi5hzfxiIQRSxM7HWChCRaGWCKkIvmOYNd0wzLgZo+0WZRYZMxl8bmXW0rnqcqjfrvc2K7P5TRtWn7QyO/EAmkkh+w=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzt00EKgDAMRNF//0vXhVTM9IsKhSI4m8JLuhkINAkXagzmYL5Eca3+TPd3VFLpvVSVvFHZc9XvszQn0gC9KNNo9tcZmnd4LLmWE7/VU76mUUDhDW8kb60='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzt0EsKACAMQ8Hc/9IRBL9PoQjixixcjKHQ2scRRTDRdN2kkKk3wWq7WX7L55ilQfaJjjyzsg0atGFldRf7tjfDarmZY+bnZpjnJOkjOeM='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzt0UsKACAIBNC5/6WnRT+NIYygWjQb4akIRW4GyiAUQoHbCoQVTmvTal8xmkvrD1lSYbPsH4xp/XAxpdQ/UFF+PaUU2jeMMqzu5qvKMcrIBJaSipI='
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt1MEOgCAMA9D+/09PLuIgm2slHoz0RngylkzMlEDSEkeLYlmOHsUyHJ/lAM9nu8hRaYybJPer/lHC/crXiHhakcVnjSeRqkiX0hp+h0+/cX0izYPxIXg1aCMv53LzzWleP9/jJsvDqyU86yTiN42v87CT3/FSm0AvztmWA6GlJyA='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1TESgCAMRNHc/9JIJ4SE2Y/YKNsx5hFgUEvBMU64sRpaT4w14UI09ndjQzDYYvwUITH3nJhueNPUdMO+e2wm3QlYNbA+6IkBNQvH97IZvkrSzMjE91UzyvV2RnoljjnmS0b77bkCYpKlpmayvcTMtrfRjEs95rGRSKH1jdFBzQWKX0sK'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzNlVEOwCAIQ7n/pdmymGwDClW3KH+Wl1bwQ9WsJO0OkHIWiQnDyg8kn56YCgJ9I6QMaYVp8qU0OUYjFcV7mSTFFxign4xeCbkMkGH88x2+Ie9jTBqJu+h1Ag4gBumATDdama4lF4+E4jNyrz0pJsuVliTvSZLVlK2BZtzuB5r2hP0DA42nkQ=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJy11dsSgCAIBFD+/6etmS4juCBL5FtwstWccYzNkB2oajlHXl6Dwv2aS1LWgNuSBFqXxAwwS0br2tPweFlPdT84ahDaUsVRs6Dh3+R0lLOonSjvc0JPBU8v3L6o/UftfxaXopavU7vSGOVPDY9PsANde8hF6dSLj4P369TJygQvn0NKE0kSa79by8J/vao53XlVN80dkAPRA4u7'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd1UsOgCAMRdHuf9N1ZIn0XQIiSuwMOKUN+HEvYeadMSKtC1vEp3JF8QqnVDOwORMkTgzLc04ciZBQRVTvgzlmJGUlSSXUlnrTlrymTMgyUu2LZzM1jBLnb0gH+Urx5+QmbTrILc4of04A0o5yYYX0eBukrBcQ/uXvhFfXsDE8AAfbpJQ='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN1eEKgDAIBGDf/6UXRdQ4zktzSf6q+WluRI0xhdlIRFbvkbHRgh4dwDn9emz0pN4gMCWxkdRT6+OCdFig3eno3GHMoq790qoWg5HWYhdaY50chPbBLV4rTqqs+cnWNOLQJr8YZLkOYfW0DzRi/d0JaH8QlmnR/oG0vCPTakyfGcRN/7jf6OWtxSuhC+77DQoEh78='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYsoqQlOKWHryKhitAijBCETwYFQ2uND6qaFTRyFUEAE2SYbs='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwMhUiK8erZBgqHGkAOWCISD3DSuGAZK5RhaMKRxUOC4UAMi/NTw=='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt1VEKwCAMA9Dc/9LdwH2osaZIkW2Y3z7aIgXNdBAwWQh3JFAI30DkQahtijZhxOvBTalmoGpoDlJgIaGeCqknzUJPxUdVZSOaX1V/4wcd9AdkEnUtGQ3mEhot90Lkm9CHbRcgfSsO'
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1lEKwCAMA9Dc/9KdX+Ja1wUXmEj7aV8hioJmXIF0aohWjAEBcTyMU8AX6HPA1W0tg36qcw0cA/wDCbNaVAA9lB1Sb6ZwbG4O3++5f1wFCxZchqaFIcQEztNG+LCtg2DG+L+XXUFT80U='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt01EOgCAMA9De/9KaIB9Mp7aLgNHti3R7BBIAgEUrDCPQHGwFCGO+TFxlQ4ccmU17k611Ter6ZOhRQleAFKYTcmP9NDGi3nsGobhD7pB9vd1JGdWJ+8WSJEnyOrJPSNLGCqlNnfj1c2IVSxq3AoGaWO4='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt00EKwDAIBED//+n2oJTWRnSXJBTq3qKO5KKIyIFHtjMNySDsWdE1y1lAXXkmG0hXR5l1U2avaG4FK4dkl4SZWo6V13Mf288IOYkVlwxZDv2tfJzpOMeq99OsWbN/s1dpOXs0UGZtjkVpNos5irAbPQF8lnDk'
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt0sEKwDAIA9D8/09v7FIWWiVuekuO6ZNSLABcYjBoVY93bCNPzWZZUzlhnz6xwXGHFVKx3ancXLUT7/9u87HNJpi322/P/9fW1vanpUKwqxRtENuDF+wauAEowpeh'
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt00EKwCAMRNG5/6UrXRQZMZrBKBYyy/R96KIFgEcYDngIEWjpY32v4du6bxM+K/59MvS2iPOeqf4r/H7T1Jc44ZVk0U/bjh8GzUd8j7f+r/Tp0//Y82WPr2fBm0sf67nx+VoVR7WarA=='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1cEOwCAIA9D+/0+zZLvMrRg6ZQdCzzxEo9FMDWSRT3BGq44TDClMWAvAIbTFs3qF+INSQlrcZBYZ59OJIiCWb8iHFX86uBTyvqRKX53ELvQKiT8bY2nSpEk14n/qjPA1PTIZk5L5zgqRgDCp+MoBW7lj4w=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1kEWgCAIBFDuf2lauCkChdFoM7PVj9RTn6pIBFJtTEYAUmHyDNmS+XXEZptFddy8RnIsqtPEbK+trKakLs4FXLqNYX+0wu7TksxOw1h2t/zFSofcXgpkZGRkn7H1s+gMi3qesNmnBmzaM5nDckrLYOQCtFB33Q=='
				),
			],
		},
	),
	"N": _Letter(
		adjustment: 1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ3QQg5Znl5yMHl6yP0DAlzqaSE3UOFMr/QyKkcdOQDQ7E6w'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzt01EKwCAMA9Dc/9JxgqJ0iaLTv+VPHy3SImkDC08sGMN9g7VQ3+zdGyH5xllfu2zFlWFujjay/YaxfZuX2MNoR78dMPnX6lla6E2Ri6aIXsgETe1L0Q=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt0sEOgCAMA9D+/0/PZAeCMNtqNHJgt5V3GAMgjEKWp5SExX5VI+xa4NJ1gVQZWmoqT5GRa6hUfbF25Cm6pIcqu9sjj0o6b+tvPuFHisAIx21lqNPvJKoFUmVoqalWVWRJtTwATUgUFw=='
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzl00EKACAIBMD9/6cLITBRV6pL0d6UOUga0HggKQFDVwFrtABCoiUF0qkAFkEyWoB2gHZzMC3/DMA9jwfZ7FTEC74WJKZV4nNgTjUGo6TA5wkw/SEWAR38kK9t'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt1MsKwCAMRNH5/59OUehL09wsQmnBWeoxCSiaJSIWLSxASZ9Q04FJuWVv6rG53PQNVGNBUmJ1WkpaoalJ5cj7jbKqu5xDBW8i93KW+qmKPqnLaqi85qPyR3xdBchYtGwefxUW'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR0MpDSqmgGQhisZVNL/QAC3JppKD+LIGsiUOio9WKQBotewSg=='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzt1MEKACEIBND5/592uyxkO45hEXtork9UEjJTgVTJaFEWM04yFH/adMymTDJcXcy+RY3fEs6Y41jLSZouLpzyluemB03uffkPbHV2QwYedzCaI8yVfktdHpCR7S8='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt01EOgCAMA9De/9KYYOKK6FaEJZrYP8r72gBA0YIRCU2Dokufvkh2mIuzbC1Xkqx1gryILtlG0rQi7yZjt7qMpj0l63G9dKLPW99jxuPIlj5+LKMd/XJGlvY7rJJWKXLvZdnnK5JxKA+9AePZsXk='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzt00kKACAMA8D8/9OKIu5d1F4K5pY6p2IBBCnQGZGhxqOZXWsApVqXTBoZmSUaA42p7tZ0c9aUFyuTm43ZR7M68lP5MCQ7N9yevxlNGA/mxZQumV08mv6u+SQTAb26VtQ='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0kEOwCAIRNG5/6Vp6sLagvjTaNqFs34IRMxgRCGUOsPUWKrJf6QvC2SnwUMmo7yTcmVI+h2BFJJXQS7bp6lEbmp4zxX71rNCcsGXV5lfHb/PLbe8SZss/SSRjGd2srvdpzKFhlDJAa4Qt3M='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzN00EKgDAMRNF//0uPCoJNfikIRZxVeJsMhJAesHRDtFWwjFYEC5ZzkDyxUCSWtuaFYFl3ceGtEktr+IXEEst97iL5h0y+5KIDmuq3Vw=='
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzd0tEGACAQRNH7/z89SaWaliJ6aB5ij1jDStvgMyzAAs8Fk+Fjkfp0aQkEFyLhPidrcjeXsMKIU/cvRCZ+DmwO5JHIRJYEsunJRQ=='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt1NEKwCAIhWHf/6VdNw2dpn8wGGw7V0FfZhSp0gh1I9QRKmcw7Kh8iybLUprvEKkZ+wUXasahe6lja3fU1G6orc0odLeHdrh36nnFjNJ78s+H0bp28wh/+jRt/lo3RWi2RUYX3US6bLzO+2kjlbpJgRs5AEAuT+k='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzdlFEKgDAMQ3v/S09BHLVN2jAmiPnTPpO4TcegMj6ayCkBaTHbSGmJ1MwEClxHCnlHyj3m0GhmXjwSYg11D8rIOZCoogOURoFI1jIV7SP5KyeKrXQyr/fDU+W5cOoj1ynyzbxZDEdS6pdrIXiVTa+7z55f+peue5HhAZupymA='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy9klEOwCAIQ7n/pVnMotFRKBpcv4Q8CyKqXSKakDSlIAreoCoLLtz3kgjizCVEebG1mjMHlFdRjLgVpfoxbGsZUmA17Rmn2pkWNA+x1jnK+QpDhV57VqUUWHAEkcEXUQqpiwUP2jqzGhlCvclwDli4jT+oAis8HZcb0QPi28dj'
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAARMMFhVoyga7CoSyQaziHwjg1TlYVAyWaKVPWh9VMaoCUwUAEwzyAw=='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzt1MEKACEIBND5/592lw5LaaOBHoR2jvVQQkkkCCIQCbzxb12BtkJbLWy1Wez7wWacJoVqlRAfYwLnwgUHIpWSF9SIyqGR/Yh37Bd3CfHFWkwL205I2gkGyIc85wGEjmrA'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt08EOgCAMA9D+/09j4g4wWKDVYEDtcbxeGABIfKDqM5rmKpD4O3RQcKNG1wU3Y7UdSDrMTO08oYsGqTuXlsFMzazvvraBorvRVnJNc4113upjethoNLH5X++pU/XFh7oYstpOJB3lG9oVGJ0bBz89a80='
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzt0lEKACEIBNC5/6U39qPNynRihaCaP+0RpAF4mIB3YCxKTnOdlTXaKHew7u2Srk+0s944wD9ddRTkqg8e6aDtSnejsOOddR7e0hm0dfberlvqROm53GKcmtOcpI77cAIpbelB'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt01EKwDAIA9Dc/9IOOhgyYpvAhG00v32iLTbCCBysa4zoUtLI+YVmtVSXne56PhfqnKc9mt1c05B1LhLja9W6+vm0PsO1j026b5+SXu2393e23vrNOlTNGnFdjUX05BIf1SscMhw5AJYAcsY='
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJzN0jEKwEAIRNG5/6UnWVgh6i8ssiFW8opBRcmthNZR6irAMyaypAMTmcjuDuxRZDkqIorFcV81kbV5yaqeMU+t7vGxxTGzmWx/08D8SzPZwgsu3CL6'
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzV01sKwCAMBdHZ/6bbgiAmmb6gYL0/ykE0EQKbhBM1BnMwn6K4Rn+mba2K67FVHfNG0zv9/qK1pg8VV+nAtfoMzXypteO/aZ7Dfsg1jPitDllN0wcE3gEf/XCs'
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzl0EEKwCAMRNG5/6WnIE1t/C0EEVpwFi4egySxpyOKYKLplybYvX1ae4OV8mjxD6o0yNJUp2h3gL0tmzjfajMz7Cp3c838uRnmMQeGZzjk'
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzt0m0HACAMBOD7/3/6ovS2TppE0X2JZ80ykZuBMgiFUOBZbYpFu5as6cgFmLi0DBmvKxV2JJ43xQ8j1LsaUzBb/zpRCq0djXJZu5m3Km2UkQFNEYmT'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt1MEOgDAIA1D+/6dxJ8SljDY7qett8S2AEt2VmKQlbiOKZblFFMtwO1zn6HLBq1qI59Ncceb5BBps47kIwVGfVBEaR5E3RZlPf3exPjSXPn/elvUlsP0071s6/BO8/8E+H7IctlbwahLEF4PvczjJ73irXaA35+zIBcT0JiE='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1dEKgDAIBVD//6dtL4FLXfcugwLv28CTcwip0hGe8EZG2HrGiAkvQCNtvmGST6Rm0TY209FRb6ZjOKUgOStfN9aCxvajgOn377Bzbz6u2VfK0EszL+ctrTDIFTVMmzY1BvsdXQoYk1w1NYvxErMar9D4q7Z5bCCibL0xOBg5AJ2ITQg='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzNldsOgDAIQ/n/n0YfjHFCS4dRx+M4a7kkmzsLo9kGaXuImCmsvUDq7kT0foDIeDUlgUmfHFyufLC3MWihAK3JMxVRS2KK5BWB0MnUHpfdJVExYMi6aKZMFlfueCCz80y0WugfJHwHvmkJ2TNyrTk5JsuRlqSuKZJVl0cC9bjcD/RYE+Y3LeCuig=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzF1VEOgCAMA1Dvf2k00ahAV9alRj7Hc3YGQ2uLta1AVW/HystzSdivtSRlDfhUIhqXkI5eB3TfoXsGNC/rMQ+shjyn713ExyzPrqRhPk1jjpKldRCFjg1HT0ch0UwaPkMPRHzeQp34JbqVjvKHfhVHDb+A1twVxaknz4P7NbsKpODlcyhpIUli9mtrGvzTq1rTzqva1JuQHaSUirw='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd1dEOgCAIBVD+/6dprYlLuICGteVT4BGcPMTcFxEn14ykFCZZn8odzQesjhIBq08CCRPT0mj2WOLuI2x7+uiKlG+VN++dK9mivDyDEokewi5pWSgVdmRUc6HkFnm309KG8dCLJQP5SvO0RLeMHtMbcam80ozkuAHhX/5OcHSOlfAAznChlw=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN1dEKgDAIBVD//6cXRSyzO3e1IfPNPIqrqNZUiLRARPUZEcs21GgCx3R6betBv5iwJRcLKPGj3xcrtbv3B/cyGpDWPQGVf1qlxGiVxvSVsovYgEcc8lUadbiamJ0dvZG2foLx8Wu0xf53h9DjRVClRI9vyPQ5rtDqKqfvisVF/7ht9PLRzivhNzz5AQwxgcU='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYsoowlA4tRUgqh5Wif2BAQPtgVDQYEwmpinArHVU0qmioKQIAFiNnlw=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwMhViKh85CpGVjwSF/8CACFOGlcKhkBLJUohX+ajCUYWjCqmnEADN19Ml'
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt1VEKACEIBNC5/6VtYT8WGmWMtShoPuOhRkJmOkiYKoQnEiiEMxB7Ql7RcRSNByfveQWipn/RJ2OEMSRMDq1K4b0r0YT3D5cutb4XXTQdmURdSUZOX0LecBui2KQ+bGuMby8K'
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1lEKwCAMA9Dc/9J1sB+lWQmsVSjm16dEUdBMC0SXDfFEMRAg2kM26w/kPVYYFAbPO5IJfYHdcOIhnNcVocAqYFoKjuQsLLxg0VOQH9eFF7aClgtdCQJ5Ww8/ttUIRkz/e9kAoZH5Pw=='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt0jkSgDAMA0D9/9NQkMICM0gJyXBEpeytbABYvGAYgefAqSCK+TJJFZcJOTJue5Nt5JOzjCGMRBKZQSARXuhIwtJjSalscpWKi7cQnY35+pcQyd1DxB+bZJKc7BuRxNohZeiTPD8nrFQS3AqhCFvr'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt0zsOwDAIA1Duf+l2KENCg8BWPoqER8ObQkREHjyynX0hGYQtS7piMXOoqWeygTQ9ynTKMTdXMCvzrLMgix6qXbuCtWt7mZYUi0MexikGWfLHFAtZ0g5Z+pSLFTvFftVy1g1QpmOOeSk2ixmKsIa+kzRu5g=='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt08EOgCAMA9D+/09rvCCNGxRlIcH1WN5ObABwiEGgVT3qpPU8NQ/LmsoIe/UD1kqUrXXf3hNzLL/OtXxWqy3sFfBsIyO/9cYqE/+xbf7Jdvch7WaWCsGWUrRO0hpesGXgBKARmZ8='
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt0sEOgCAMA9D+/09r9AIlU9c4CIf22L2eAAAOIVjgIYxAsa/10Ya7/36ccK346yL6OLt5WqR8t6r0w30L35HZ/q5E/xr1UZf55Mpe8p+bwGf+m7190nMzx7da8I+xr/W8yfm2OgHCF5mt'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1OEKgDAIBGDf/6UNKiKZu7xIieH99ptubFNlI7TIJ7KHq44TMVmY+EtMCOr6CXncm8CcBcnEnY8gwpF7sxCx89GEAa/Iv1J1rNePlU4KrrAhgSc2pkmTJnVkWAASv+eMgDFdgne2EAkIpYqPbBOdZuA='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1EEOwCAIBED+/2l6sEljCwikbg/dPTsIRlXtRFoKxmSkQSpM5pAtmVfnbRZ3bbDMsLLIuQbEnF4xTMps8kl237bFqgjN9gd84Bcr3io4++yh5T4FI2RkZP9gzyp7mNdzwKJRHRb2TGawnNIyGDkAAgN/1Q=='
				),
			],
		},
	),
	"P": _Letter(
		adjustment: 4,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYMAO/gMBDimqyP1HAtjUjcqRJodNLS3l/mMBo3KDXw4AIjTuIA=='
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzt1EEPABAIBeD3//902GwpPTo4sOkUn6kciBwMAFxiQ4+WhqAeg5rZMubOar6+ZFd50e4NJszcu2cMzMa1Mdeb5nPTfpaxdPoNxAYFMvu35ywi/tHUKNpJ6zE='
				),
				_LetterImage(
					width: 38,
					height: 38,
					data: 'eJzl0EsKACEMA9Dc/9IOiAzWJDXLgemyffFTYASFWZm6SZTKlJOsFJSKZO07yT0F5R2Z2gYXtUaZQqbmJFJyOx9TJ7SqyFZBLLyR9oQoLS6ioPwdBeW2dOyUgbJP+K/aXKte2cwfiqPqMg=='
				),
				_LetterImage(
					width: 33,
					height: 37,
					data: 'eJzd0lEOwCAIA9De/9IuLplBKS2fZnzCQxMAGDowwwKFEMICapDDgt3EHDVHIhvyqgUrqwbVA7BgpvvjuQGAr6gyJfiQBIjj2fpMU/6bX9CxHgZG5x7eggb0w/+CRaryA3Gtcqo='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzt0DsKwCAQBNC5/6U3SIqg89kUwSI4nfLYX9WmAOgFssKT+x3JUKIiTKzgvixoOlvdtZ+nfEF+pPjAq+IDC0XNZb+g6JOVWmn+cFvro6xT9kIrImbWqBw56qgPVEDVi5ELt1j0Ng=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYMAJ/gMBblk6Sv9HAVjVjkrTVxoTEFBGP+n/WMGo9MiSBgAOV1HL'
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJztz0sKwCAMBNC5/6WnuChNYmYKRSilZqV5mg/5QgCwqBhnjLOy64m0wCWbefoQ+5tiNyzGdPYJpuFUZSFDc8oUrrvES7PntL/oZGYU1vd7wo1t/i33SovkATnbo4c='
				),
				_LetterImage(
					width: 42,
					height: 42,
					data: 'eJzt1M0KgDAMA+C8/0tPUGQ/TdoM8SL2uHxdWQ8D0LzCjoSnMZQvc71KrZnkWsmo10hzdsqxGveGHLNa3qkv4cszsyU+LgPO5Kwr2bUjL51dZF9CZ5J28WrSLrZJJoXNt+GLKyXf7S8fywlXsuuUHImwg6c='
				),
				_LetterImage(
					width: 36,
					height: 41,
					data: 'eJzl00EOgCAMRNG5/6UxGoNSfuks2BhnWV4LaYKkVkWeKZl6HJM7xTgGHJrAxiq7qQIMp+8yT31p7hPHyDHngWHiKj5mosvMmy1Md4W5WNZcd8IV+d9Kh+N2oGVyWww/71+mjWvHHMT6BSY='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzt0MEKwDAIA9D8/0876GFQk1gpO2yjHuURgxGvHgAtNKanbik90oRMzioluyzuIKJk2+LOnqx6F3L5r1/JaEnON1I02Zbz2kleK6lfkldZQV6xqJT0BilZ+fYPSs+OPPJDsoTRQmMuI1TJbw=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJyd0kEOwCAIBdG5/6XpotFSBlzo6vs0IkaiDrBUQ4QIqiFC9E4yrfzZTg7N7hVrmTvB0jQwCJZ87R8hSpPckpeHM4bS+ckPvYclLHErzSeLKg83+2Or'
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzt0csKACAIRNH5/5+eCHrIlSBp26zsYJJkl6MEFEHUE+9pJIESKI7wllktYSH2xvkc/yKmuCr15VLv5XLnHzDPePOXSzHESAOrWij0'
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt0DsWwCAIRFH3v2ljEQudx8BJkaRwSrj4ofev0qpupAxvagfaTHJ2k1QdU3RA115MpRFRqCJNp/Ue80PjzDJgcQ+p7ocprpIoXPEK3Roh1TrTrOintW7evrRK69iijik6oJHbqXH+x4ce+meayF51kxbcyAWv2074'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzd0lEOgDAIA1Duf2nMPozC2kIWzaJ8KXt2hOj+cplZx1TKzhrPBblkRQCLZ1jlz4FCN7D3GJ97xQgsXCvNnlR4MM9NEabC+4p1quXEpt2KKWa89f8hNZNZQSOHQUwQZ+tfUxuu/MtgH99FJ4scHgUtd8E='
				),
				_LetterImage(
					width: 38,
					height: 37,
					data: 'eJzN0sEOgCAMA9D+/0/PeJAw2o1qONhjfcxpiHgChBHcsdAWAo5DiqcKSEjC6UkDc1047jw1yp0KfUwta42ay17hkzo4ylTywxk1LwDFU+kC8QLSqwU8tRTd3yoKrLcmPEVnXqiDo3621nCtuQCbiErg'
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYMAH/gMBXgUDouI/KsChflTF8FSBDRBWSn0V/3GAURWjKmitAgDy1cpS'
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzt0EEOwCAIBED+/+mtvTQiLBQuxkRuuqOCwN6SUVnOhXz1Lng6qYqw8SzW/VXYU6rbP3c6TbVEOvb5ArHQl1WFhELv1YWdT63c6Z2PoW/GU7G0IWwc/OkVV2wQDCDLgQeUTjn/'
				),
				_LetterImage(
					width: 46,
					height: 46,
					data: 'eJzt1OsKgCAYg+Hd/00bdAC1zTZQCMqf+byfkRCA4i+kel+Z9hL0K9PDZIZWhdYsuW0OE/5cBfrglbrZ9vQFMo1MH9uRxhc1CWbqPjF0VZj6TMbzolGh5i9Lh8hPR4fIm6Rnkpsv9T/e0eqqfv0u3QaGrpIntQGRdzEI'
				),
				_LetterImage(
					width: 40,
					height: 44,
					data: 'eJzt1EsKgDAMBNC5/6VH3Kj5dqx1ITjL9EEgKQFAJdAdFIszqmstYlSX4qfOU1cvbVJL6bhP7+hWtcDxnguDKN3+Jro4qO+7YBtn7MAdeKWD3dVsq8T2t8CVS8cX/j0v53Hgst38bsLRnpEyG9m7h6M='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1jEOwCAMA8D8/9OpxESJbTykQ6V45VBMJjL/lIiw4YoNN00uxZlUI2xdYC1EJayPIXysniiblYe0aWeZo186XY0GUQ1r0R5XjQ46dJxhusB9Ijhk1aQG2yQayQbNoNjg6NGjP9Q37H9XVh5opaqc'
				),
				_LetterImage(
					width: 20,
					height: 42,
					data: 'eJyl0UEOgCAMRNF//0vXDQp0viYqK/pCCkOhYqGWCKkIIgipCELqqDa8ikUfTXczUzaPbD8Ns57/g2G2xWtIX+2OE29PzF5m/pBaez+Z/1+ZlVmf5UsboxLc4QAs0K5g'
				),
				_LetterImage(
					width: 22,
					height: 46,
					data: 'eJy100EOwCAIBdG5/6XpojEVOmi70JW+oJKfACGLRo3BHMxRXmt2lMF8nDM/VbPvtNlO5fn3cbCeTimuXS7/tWZYvCquc1orrRlu7gqvmh2vf9Iu9XtS3hqucU67OQzRC9Ls8R0='
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJztz8EKwCAMA9D8/09HBHVtE/Qw2Wk91QephLw4MKQGMfTJaYxRCQax+TjYyjymG2ognzW/vzeq8Z7FFrlYMLOFwFj1bGlj+tEQVXbG374wirFOAzFYono='
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzt0EEKwCAMRNG5/6V/oWBJ0tFmUReFzio+MMbAhsiiUamrOlM6a8RZVBkdp4Zeh6CuTC+s+tcBtypOeV3zf8sSotryfmmmeZTHbYBRjEJb+fWDSo0zOABwFRMY'
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzt0kESgCAMA8D+/9OVizrQJKWDBx3JkSwiVfcPxiq2pWJPnm2yK/kZFlOxjGOK+VBLHrvnOCoIZ89AfPb1TFs5VPgVVrgea8+TsfZcjvWVfKwUBw3leBlyfmLk8jID1xcXfxCwjGOKObeRS7vKM7355v/lqfYCvfmcbTkA5MlQBQ=='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt0d0KgCAUA2Df/6WtoCxw29kBIwzPnWyf+FPrP6Zk+8fkxWUMWu45Vy+YgibbF4b2mekagYHxcEMiatytWijPC4zuAyOv962Jvqsz/BmJoc84k+nTwMBQGC+wtsJhdMURRh4Km7AvDO0zIwEwUX+QccgyyywznbFIzfYfxgf7bN9Lr7M='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd0ksKgDAMBNC5/6UruBBtZpKhtSjNzvSRH7b2xwDgOkPiivOjZjfuMEb7ZyVjESp5rwkphw9ZuWPSxpf6HislvRxfIC9atFklk5xx5C6NR2ipWawiGZeMMSlcNduYlD9JVvQ9+XH7DQcdWWnDi7o15fsBSct+yA=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN0UESgCAIBVDuf2lr2iT5+QjaCLvghaCt1Q+5I0AntbzxfE3J/pd1jSjmgyAa9DK0dSrIkQFBPq3JLiAZ04NHlToavcK35LXoS/6Bcc2zxjZ7teigmlHQi1FLQ4m1SVc1o9q7Unffr7OjxPSU/1On7/D04Ok1T49S8n0ivQm5ACU1dd8='
				),
				_LetterImage(
					width: 42,
					height: 41,
					data: 'eJy10lEOgCAMA9De/9IzxkQQWujU7XN9LGEQ0QoIszISFsZdvtxhDOVLiQkU+pEt8RhIy7oVsrUNeQX8Qmwnzsi5vZX4IAtGlkixPAb7YD2yzzx5pgupTqkb+nJqbbapW3j/NzOSnUzKgpEF8r+JQZ+N1QEvMBAp'
				),
				_LetterImage(
					width: 46,
					height: 44,
					data: 'eJzNk1EKgDAMQ3v/S1dEkG1N1kasmM/mJRCm7oPMXJBKn1LYasAmaXQWCPQ2IdEQponJTgPB2wXwXaMHo4O+LDoS7mdwpaZC27c0msirO+k1EM8WtKuO9O020bb8RHgJTbIlGh2PCT3c8+eiNINvs07D+BO6sfo39OvNzj4HqAOe4bl/'
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYCAA/gMBITVDQdF/dIBLz6iiUUVEKMIOiFI9sIowfIfNm6OKRhUNNUUA1y1A6g=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYCAC/AcCYtQNc4X/MQAenaMKRxUOOYW4ANFaBpNCTF/j8P+owlGFowqppxAAUrbYUg=='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzt080OABEMBOC+/0vPrpOlU/1JHFbMrXyEBuBnkTcBskLS06ol+MA0ImJAekohtjSPwgdg9yijSMcORHDRtOU+JA6aRouINMYuxXq2lPh/yECqXTVERAFxcNFFxyDbIECAB+1jFTI='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1UEOwCAIBED+/2kab4jrSsU0NWFv4gQNHlS9P9ISU8egmLTlygjrGoIQOYg2MxAf1a9fXQegEzA40oL7UENw6L0NbX0Kff0bKD4IIsNGz68yRWk4PlAGQkQHXrBgwR9Dxuz/sMgDKmMJTA=='
				),
				_LetterImage(
					width: 51,
					height: 51,
					data: 'eJzt1UkOwCAIBdB//0vbRdPGgeFDsJvKFh5iJBEAWizwGUHMYYwEYZhAPFhJdGYSGQp5z9UQdWKPCMlNZCrhyVuUIEiQuyJOljgkSkS1g6yQJD0LkAeWk8QYOaJeWWlmvYfSy1oX5Xxxx9rwQbLE2IVD/kRmRpLeEZUXsXUKPQ=='
				),
				_LetterImage(
					width: 55,
					height: 55,
					data: 'eJzt0ksOwCAIBFDuf+l20dZEZfiJpgvYMm+CiUREl3/oOHsmyFx4ZEbLMh3/hklWYwCzCR0LO0nmM26/mQ0pH2u5IKOz7A3F2DzFshigGxmDt7POOtmHLfWh4jDDz4GNy4yzsFH+kfASlrVshOHbixXLYxO1sw7bwjeb5/dP'
				),
				_LetterImage(
					width: 44,
					height: 48,
					data: 'eJzt1NEKwCAIBdD7/z/tGAy29KbW9C0f84gkFgBIMtBosx7fWLGBN9bx1E4qiqzhJuUU0NMJz7UstaI3oM7KhiXjdOydXbA4NuV9O/rYvhUdFnoFfnWlPvzLdMKz0vjeHtJi2WWPbbCDD9wFkUArDg=='
				),
				_LetterImage(
					width: 48,
					height: 53,
					data: 'eJzt0ssOgCAMRNH5/5/GaGICMm0ZXgsDSz23AhEAkrCwwUOIUCzVx8249yPDm9VUT5r6pR+Ne/+amzfb4nOwyqdNHuy2fX8D0eN4xbMm8t9oic+qhf5pooHSMPuQ1sM+X1d0jvM70A9P8K+SPD/S8f/zZRPbC5JfCD8='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1jEWgDAIA1Duf+nqU5fWQIIPF4Wx5AvVxTH+V7ZXLm0qsbmuQzV+EDIsRUAY7BfG11MSRr2HhG4MA174JaJ+oyY6uT0gJHhmMXFuFt1EIbhXSdZGSEB4mg77wa6MwDfuExyvI364jLB8kyZNPkkEkfvXPGsDWE/Zew=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt0lEKwCAMA9De/9Ido+xDbNJ2KIg0n+rTiKp23ohIGVg2MxnzjeaFsfjUMvOAWzYQ6I7/GW/jDGf6gzW0+T7mv2GzK9i8S8DQ4ZzBzrxiloHZY9g0FTEPjEXACt78oC8KxHLGAGAxadasWbM7WE5pGVge8IUsRQ=='
				),
			],
		},
	),
	"R": _Letter(
		adjustment: -0.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYMAO/gMBDimqyP1HAtjUjcqRJodNLS3l0Nn0kBsI+wdD3FJTDgDIkW6g'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJzd1NsKgDAMA9D8/093CkLXLO2GF5D1qe7MLopo9mIByEUbrjpbCe4a3MJSMNrrfT1kdnIR9w9mmdF7XzFk1l8Ho2zej6H5WdT8+9adLXLyvYXFfc+y7fG90GwT9aEpyn80RzWUvmux'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1MEOgCAMA9D9/09jgh7Y1pYSL+xm9xSY0YhhVMzy1E5GKk8x2RWCUDWZcyZ7hiBcw1NLY6O+lqfCU7NjKTidy1SFVCUpVYCBC0mfYN0NXA+gqiFX7W2na6qWBA+4hjs1DpT8HnP6X9VFqSpH0EqdHG7uDblS/9xblRgSlg8PK0fj'
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzN1EsOACEIA9De/9JOXMyEDi2wcCE7yfMTRIFVB3a0oEII0QJpkKMFbGJOml8iG7FqC75sVagZQAt2el6eGwD0FTljwYtKgFgemtdMyitX3SEOY4BvHw0Wj0w/nAH2XZTnHgPeRQP6eDwADRVIaQGcuAGoizfoAVOp3z0='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzdk1EKwDAIQ3P/SzvKPoYmsR1shc2/hocxYiM2FYA5gZ7CVee7RQYlOsKUJdiXCZrOdnf2ecoF5EcUL7hSvGBBkbn0aygSmVKRsuBS66XUOd+j+EB1Rt1QUqHELGTZf4sbmb5w0WvUE3evzCulR9xONVDMiVEHdQFI4g=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYMAJ/gMBblk6Sv9HAVjVjkrTVxoTEFBGP+n/mDz6SmOIDC5pWiSHwScNAD35wU0='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzV0ksOgDAIBFDuf+kxLkxhgMFF44dV7dMymAIvlJlJ7NiuOtedrVdac0y7kdMHvr84bOAmprJfMASHUzay9Rx2iHkW/1DMmeaPrfaxT8LRBs6tZqYwPH3Oeoe/cBUHVndt4PxTF3MGlPUI1wqJwAH1QQki'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd1dsKgDAMA9D8/09PUHR1TdtUEMQ9pmdXxgZgaA0dCU3DNF3mepWxZpLrSHq9lmLOUo6j6d6QtlbLs6pL6HKvyRI/lw5n8q4rObUiD50NJA9CLYsC6eNMkrv0TA7zGJLOwwWhnLkiR1ParJTpjprSLSCT7gRKib4k04TbOvNMNn6rL0uLS3npDcg29DY='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzV1EkSgCAQA8D8/9NYWAgaMgsWF+ZGpsEVAJSokDMhQ6+MsR24MkY4aYh9U+2mRDC5+i4zcte0TsYgY2ojYfhVHGbYWebNHNNdYG5mTY5nCiX/Xn9x00zffc2MM4VN4bEyPdxlnL0swt+GLmcZunHPYMG0sTaiYT/cEWYozzzuAjd9jJ4='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd01EKgDAMA9De/9IV9iGYpDXMicN+1keXVZa5dUWEhUZ56pTSB1TKyahgcjWLM4hRMm1zzpzscjfydl+/kmlJnl9IkWRaXtuV5LaSeiXYQhXyFC7rLyyU6kU8kkWeXqZuQwu/lMdMLGWjd/SG9N6mLzmJkjozyfJ2n8oWpoVGHRWB9DY='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJyt0kEOgCAMRNG5/6VrlKDT/mIMkdXwIIFSFHVIlGoCCSRVE0igMXGa+bE7MTS7Z6zH7IkoTQELEcWvnUggm3hJXN6RoOTnjfwaYwOk9oKy6Jd9MqfUiytA4lW+fdwfpDnspAMD8sNL'
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJzF0UEOgDAIRNG5/6XHaKoOnxWpibNqXhBatMdRA4ogOpPfaaWBGihb+JX79AgPYm32Z/sdMcVTmT+u1ea9lLn+VxVRyr6iLGeVt4sz+lRj8Pd7Nrdqiv8QQ4wcSj7VOQ=='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzd08sOgCAMRNH+/09XFpogc/sIMZo4y3IoWIP7V7GuG2nDk6Yb7ErR2yRdxxQd0PtaTGUholBFWu7Wc5IvTFwyDBjcJtX5MMVREoUjXqHLQki1zrQq5ru1bhbJ+H/M36NU4/NbLejUHPpgc75afs4sPewNtNN7HWLzFRS9XbJJn35bdATR4DZKw4vn+T8tpHfdRRtu5AB79IO1'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzFk1EOgDAIQ7n/pTFqzIC1gGaL/Ey7Z9cwVN1cItJhKkqeOp8LZJAVAjC/h6n4OaDQCezd20etiMDMcyrHVlI4mEYxMcvM+xRTquZ4UUwxijGK528e1F2UvQuSf3amvbhWJ2CKGU4HpJQV/hzYpX9SwytNeqs+J6Fi9SjSi29mb7zI5gEMHuw+'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy9k1EOwCAIQ3v/S7NsyRaxBRtj1s/uCQVdxCsgDOGWBS1BwOGQ5FEFSJAEhy8NmO2CY8+jPnNFhT6mwlqlRrOnsEUdLGVScnCGmgYgeVR6QBxA8hxgg3oMi5ITp/T1irmMvp6Wio7iqKplRen/on/dtdc21AN4VMxrLk6SdIw/qAOlzBlj3tgFChnrPw=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYMAH/gMBXgUDouI/KsChflTF8FSBDRBWSn0V/7FwB7EKLGKDWQWu2B9VAQIAMSEWBw=='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzV08sSgCAIBVD+/6dvtaiRt6QzKjvlKOAUsDbojizvC/riWfjZRlWETrdC7kuhT7Fue+40mvol0rHPF4gFv6wqKBR8ry70fGxlTm88jCi6QLDGXyYOGRelQhamqDfr1cfEdt/6DDH0v+hycGI74QFkeeAC5ZaCqA=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzl1UsOgCAMBNC5/6Ux8RMoTkuHwEa7bN8UY4gCKPmCqs/SdC6CvjQdRrj2Eqs0i7yGYYT3vYB/sKbNeId+gKah6WssafxRk0Cs+8hy3SSS+o7E+6RVzuF0ia/ZYKmm97tvxdp0g2tAJkld9mvTzejRO5nQ7Tin576D9PlcDdb0NYsMtPhr/6w2gYyuiQMcIsB4'
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzd1EsOgDAIBNC5/6UxblQ+M6XaxChLeLG10AKwTqDv0LE4o+ukRY6uK/FTF2nIU1vkSjpeRzsLrVrgbM6lg6BurzVdPqjvu2SFc3aRO3DHwffqzifIpsYX4ZJe7fL8+QR3lxTpYertWw71TFRO/e+Ui0sLN/m+pK0Q5wrSVTXiJPyLMzLbCm8oOTkA'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzt1kEKxDAMA0D9/9Mu5JTGkqNDGhKoj/Uslg1dGnFTAbBhKxt2WvwIY0U1wtYJ5kBS0vgc0mXriWWytMgy7Rzz1y8drmaDpKaxZI6pZo0VGmMpnWA/kTR1uJM1uR3KC+oJWodqpIepR/fbeq5T3+Jz9Af/JyoW0cUSl+oZ9j9XWj2HnLSE'
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJyt0tEOgCAIheH//V+a1qwMzrGcxRV+OhkihATWFEEVgxgEVQyC6rFKeC1u+mg26z3p5dLbR8NZ7X/BcJbaK0iNUuPE4Yl1i1mr04r6pu2QMZ2vs+E/6LsV83xbNmnxZoIY/Nts4R03GKwp8w=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzF1NEOgCAIheH//V/a1soFdFC4aHml35gyBsIQi0QVg3JQjuS1ekcyKJ9nz0+U9Z0mWxPuX58HldNXitasLn2NNQweFa22Wti8a1q6sayjo68muCbF6BwSraJ3OrrqPj+HgUPv3Nu6mpVr9gf8q1nGJx/f84Cc'
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJzF0tsKgDAMA9D8/09H1GnTpjDBoXnqzuguTnJh0JAbzLAnd2PERQxm12Bid0+YV6gNedlm9/dGN64zvUW+mFhTScMo0+GRc/wH1eAmZ9FJ2mSYb3ZaZfvIYV+9G/09+Mz4u9GMNRu36T/d'
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzN00EOgCAMRNG5/6XHhARDh49hIdGu4KFtEbQPhBBBpV1Vi8isHmSjCrTPNvSeDErDUuEpfzZ4VE3q17XuNz7CqDicX1pp3aQi3G7frAIt/ZZ1w3otjam49KJNePy7++A8zf6/7mme2y/VGWT2BSdHnIA='
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzl1MsSgCAIBVD+/6fJjaVxL4+smZpYylEEp1Q/GFKxLSq282iT7BHXEBsVyzimmJ/SLre5+zhKEM7OQDx7PfGtO1T4CivcH+vMg7HO3B3rK/k55XGQoRwvQ84rWi52iXIx0R3iIDrK8rEKPI5UIaXjihf50E9mV21o9gUL32rciNpY4U/9CeDVCGedIO40vs5hJ7/jodYCPXjOttgAw1FY7g=='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzt1NsOgCAIBmDe/6WttiwTfg4e5mpxV/AJ0lZK3wiK1h8RF9k4KN1xPk0wJEW0XjGwHhlWYRgxPdyAFDTeo66kOq9g9HrBqNdba6zPxQxeIzBwjW8yPGsYMakYX8J1lJykOrSBGw2rLwzYmxy5LmQe/cCxRj/+2tu9x5S3DGyoZav11zNpbTztkhhrzPT/GxgVGuV6wGjXG2j4qL/pNi6SovWF8YM9Nk6bj8U='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzNldsOgDAIQ/n/n56JGiOXQhdClCctJ2Uw59b6Y4gIyxGkPHG+1NgLZ7AItWlEepOQjGs1SLh4p8IekzI8iecxSYaTixvITYsyU2SiEUM2sqjAJMa8SwLOk2p7Lc+T5iPJ1qDl60FLkMQbEJSqSCV9fpj8aUKm2f+p7UmSVZd3AvVY30M8iSfaMN32hPkDbeHSZg=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzN1NEOgCAIBVD//6etVZsK1wsUbfBUcAKdVe/1o50RoE7dRlx3Ljk/8l0jirkSRINeG72bCnJkgSD/WpO9gGRMK48qdTQ6BVmyWswle2Bc8+xmN7m6rUE1o6AXx3X1+uqAZ0QvY4Io3FcySTSdgIama/EN1vyWXb8s49ecpAMrcez9KamNMw3iT83OJ3Epkd6EHNvkqZ0='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJy11VESgCAIBFDuf2maaiZNd2HN4C94oVhT7i3MXIwVaRK2J3SZYRtClxQDSPSrFuKxQC3KVsiWFuRdwAOhM1FazulU2oYsaFkiyeEh2Bfiln1Nk2c1kOwuPOFneaVkSc43kEO2u0qko27sSbDvI9gSlmjzeHku999WlM3WpkNVyDsNUgQTuPJ3KpD/tVyY3acHegCi2NZi'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzNlVEOwCAIQ7n/pVkWkw2lRYi6jD/pKwGcmaoJES1Elb6jwmYN0kWNnhkcHTpKNISpo5OnBqdFBpyv0UY4QTeJDgnnZ3CmTIaWb2k0Ii99kh4NPi0uotKr9KOmaRkeEZ6EOnFva3TLnaP5Su15TvMPEl+AZmiXW6Xh8LTxkN71pnF+3oeVFmjl89OVa7gsZKBw9Uf+G3p76eIGX8N7vgCDG6ub'
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYCAA/gMBITVDQdF/dIBLz6iiUUVEKMIOiFI9sIowvITNm4NXETbRYaYIQ+moImIUAQDkw3el'
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYCAC/AcCYtQNc4X/MQAenaMKRxUOOYW4ANFaBpNCTJ/i8P8wVIhd+chQiCVQRhXSUyEAqFTlNw=='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzd00ESwBAMBdDc/9K/7aJT5IfEKNrs8EhiAD4WcoaD1JA8cY2qIIFhRESG9JJCbGscuQtgfXQjz439EKGJiiPfQ9JAxWwnIhdjD8V6ttwsRnknt4wint+LdJ2sCNbMcLT1v5uMBvxgklchVtyGyDZwEOAAspk7/Q=='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzt1NEOgCAIBVD+/6dpvjSDK96UtWjxpp3oyirV+iWtOJUGpau2nBmJulIQIgPRxR2IH3Vd34oDUAYkR/rDdagUdL2XYb8/hHb/GSi2EEQmGr0PUxHaCZ4c3I/7shAl4uH8lKOXIg++47uuALlfCg1dCABxWg8Hx/oQjFg/+kkdUW8JPg=='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzt1TsSwCAIBNC9/6VNkUlGdEHATyVldh+TwhgAKLHBMYKYg5wE8TBCRlAlOltNOCT5yKmRzlYSEnpIU9lK/lKCIEHeRpx0c0mUUDUkPdxHahYgHxwujq/UX0VZZhIebSHaJzZNivhBKkQG9omjYYCUo0Q+95IqW05kxU9mbv48aZlF2tBDaMNzW9LKJYbykso9HC2ylA=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1ksOgDAIBFDuf2ld+ImlTDtUii7KUuYRkpqqiMjmL0lnRw0yF9aMtJGsjxusZScxgM1EH0cyvD/BrD7LVCqF3blcJoPsDI2xuhaLYoAyzMB/ZYV1sgsz44cGt5aCE+cw1J3J4KVgPSaYbvXe7Nes6DuZvo5zmGp5mFAH8AUrUz4W9TWtaJvBQ+AZXAONNjDF6P/xxaKYoh72oDtnW9Z+'
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt1t0KgCAMBeDz/i9tBFGu/Xi2FCLyrp1vITIjAGjkwkLLevQrYwde2cCb1umYZBVXUdBgVh3+2KpoaNt9AubZVrDGcQZ2TxMWv6V8bKWfa68O1uI+AuU3uXvkrmAXrLLWrFft8ezavugPh56bN1hRJWx8DnmrthHbyncyb4V3rYxG1kx9m/pl+JgVnrBnwwZdMvFH'
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt1sEOgCAMA9D+/09r9MKQ0a2CxAMct1dCFg0AwCEsLPAQQqiW6uPMuOehju+mpnon0zZ5aNzzMacPm/EWfOWPRR7etLm/gOixveK9TOSfoV94kxL8nYk2lDbrH9ktz/VtZ7r3/8emFviqzL6+1940/+bres6H81zjLcj6wfulzhBvuqovZe47gHn5hbc9z+R8SZ0ZZwVQ'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJztllEOgCAMQ7n/padRf4CudARiQPe59bEOkqnZ9yKdEVMnFUl5PElVfiGNZiEEiIE/Ki+zDTGqdSJNx1DgiSch6hv9iI5UB1AE9xyMOJOxSRQE10YiZYEiQJx1h3XqdimkTlv2sRiAML8KAjerfxIoO3f12hOsspR2QmZuS2ITInyyjRCBiP1r3nEAJ7Crmw=='
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1UsOgCAMBNDe/9IYgy6AmX5QEm3oEvtggKil7DpLRMKg1mImbd2jflGZvWqYIQDDGoLtcZ7pacCwJz/pUZOvY/gON0vBxlkMxhbXGc2sR/Qy8vQzbHhkMQTaIKQjmD0/A+NXr3VvxqIW6180NuljhjroEXZH5j3qN9kvv5OZWfgfMMlYZoVpWyVMzbwZYD5VwqDWAbgUz4U='
				),
			],
		},
	),
	"S": _Letter(
		adjustment: 3,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7////fwYs4D8UUFsOXR0yGA5yA20nNjW0kKOlfwabnbSWY8AC0NVRSw4Ay6ddvw=='
				),
				_LetterImage(
					width: 28,
					height: 44,
					data: 'eJzd0zkOwCAMRNG5/6WdIigx4Y+FEGlwyZM3BBEbQ5IXNrWwMNgMzKYksrP5hVgq8xWLMX624k7eXDnL9e9qzaC3PhFdrkZPzcH6mXjuZzsy6r1+j9uNaPHdHfn/8PwC8yc97Q=='
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzF1EEOwCAIBED//2mbag/gLrAmJPWmTFDQOKc8hqbeoalMrsiwI02TQqpA+vVI4hqDdA9NmUChviCkZ43C7J2qgmkJjPUc7u4takouoZCqa7/XX5vSsuldCWYuHY7nPi+LVxQqJ2HNPxrxC9kBqogMFMqkt1AdVUbuyQOXXUT0'
				),
				_LetterImage(
					width: 33,
					height: 43,
					data: 'eJyt0VEOgDAIA1Duf+lpNBI2CsUAn/hEpGuNlNxFQWSetmiFL9uiYDe2B83R8AZMpUC7CXgfFK5kJ/ZBapIoikBRH2QCZo1BydAPZduOJUNBM5mp6H4s6vVxdL81BsaE4GuBXHeDgxdU0e/pHHaD4Fhm+gUwULpw'
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzt1DkOwCAMBMD9/6dNEwmz8bFIKDShHp8IzD46AHqBWmEegSQKLTkhGPUzpWKqkmhKKae0fV9Ja/cJl4BQvTp4CjmV9skJXQCr2HpFGY1UMEgUsKp2PzzO/Ss+pQq087IU8/9fuarAALo/aNA='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJz7/x8IGLCC/zAwQNKYalHASJUeFA7AEZmDQZpKvqRiJI1oaQasAEMttaUBFeboNA=='
				),
				_LetterImage(
					width: 31,
					height: 48,
					data: 'eJzl1FEKwCAMA9Dc/9KKDHG1SRyM6cf6JbxC000s5UABsKgYvZwRNgY8RDfRheWbXKzsJbvBPvM+Jj38V0Bz7GvHwTQJUoWruGbWcg9KeR4w94UBOQj/jnzBvOpBFvrlzf/R4yGkAtH4+DI='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJy11OEKwCAIBGDf/6UbNMay7vSE9Gd9qDnZGF1hupyhy1i/l+Yiy5ZpJk+9X3GOTjFm5XS53t2UHwAtIYnrdEgBZ8/CVGihsM+jKIsjuPcu81HBeruZ/LUi67MVcNPO9EygvDLrSSwXzYqcO8AmEkmvwantQSXk8X/gSE4lzE0l7DD8UL7uA9viNRI='
				),
				_LetterImage(
					width: 36,
					height: 47,
					data: 'eJy90lEOwCAIA1Dvf2lmYjIEC6uBjE98KjaK/F1jFmNitxaGVnKCKcY4ZrvYHR3A4OmM0X7ZaHbHlqQ6zZfLJr8x6rpMjsCnqBoyg3QwMilpNXRUNUNedzN4l1GGdvjHoadGZmeJeZsoSM+isAes+MlrOczIHhHmuF/zAKckgLg='
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzt1FEKgDAMA9De/9ITBLFpbBaEwQT762vMFDbG1hMRFjrHU1pGGU89s1eo7eYplEolOWMrpFnSPvRm0v2PGIxbneQ61zuzVMU5ORWfdNCyWwBJ0aNK7AxP6laVfXX+DnnLkhT8EanhwnvATvxvb5JK3VKbA6DcWuw='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzNktsOgCAMQ/v/P12Jiq4tROITe2Gc7NZs5JIhCTwAitoPEIZuSSBEErv/ssdLRxEDlTauIglBS7ORDGXUPzIo/Y22Hep6kwx2UVeuFVdWXvrfbl7W5PwYKHTZuYfSU9ABv/lI1A=='
				),
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzdklEOwCAIQ3v/S3fJLEYLcXHua3wY8iQtKOR2IAEnMAIY2QcfSOS+itafh2El+5rcUDdQyBMD6bXKMdTSCGikeYRGJ2EzER0nIy3fqvyD3+zPBWanSNQ='
				),
				_LetterImage(
					width: 43,
					height: 48,
					data: 'eJzt1EEOwCAIBED+/2naS+sqAovR9FJPNBlQilH1qyWsuxcNGSrPYl0iF1wId7vtjSjrGk2d8vMr0eI5S7fiIMWEIbmjWBtisRRrvzFkWGpjkJOEYSO7YZLQerBlphRqOz10fw6/J7U7amKXxrMs0FjSr5byd/4QLXf0v68ujJ3WB5ihCx/VoKY='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzV1UkOwCAIQFHuf2m6aDBaBj8xLsrWF6aaqno5RISYnRILQHLVJAdpZpS3PFRFjO0MU6Qg6hwq7SlcEm1+Sui5U2H9t5apskv5Rnj7nYrLJgmDQcbR0mWgkrGzWa59umPVTAZy1cQYMX/6keGrABaJdp0/Bw+rRctt'
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzN00EOwCAIBED+/2lqL22RZVkbD3LECUFQ9/UwTY3QFHX3oT3ByxiHCUH4OSEwpguXc5pyMJeqYdwYun52EhJV69odBrWzNU21bO0Cu5w43WMHIt5Sfrj/Vf3V5xxE4HsaV3nDrNabryYWIJmrgcgKFYRq6lvYdkhdWtqklA=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJz7/x8IGHCB/zAwCFRgUY8GRlWQqmJQOYZk5+JSSx8V1PXaQATgqAqyVDDgApjqaaUCALrwc7c='
				),
				_LetterImage(
					width: 34,
					height: 53,
					data: 'eJzVlFEOwCAIQ7n/pd324WIdpaIm2/pl0gdpIFjKu7JTyueE3ZojDBTbojhbDb4MrwhiV4LbA8TShD9LqJVAI1skOvZ6NwQJbo7wXrDajWWsUY2siSbMMxYQbnBnzF1wj8BGvyEosOEOB4g4hN5JQCTc1GmN9d/3F1LzAEIruIA='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzNlFEKwDAIQ3v/S3cwNphtokYqzE99qRKyzdleQ6Pv0uhQ8cyHrWM0KY1Gkm3oSnCfCfjiTtqMc/TLwJWYZhv/QycFCWcYrt2TpEufp0Zn+bozKYnGq6/P/hBX/6Qa3RBLPcSijzVnbC+85SsRaXodihj3yqdXCeyPrTyaSk7RWOHRWBIGADwaxWU54QLng0sK'
				),
				_LetterImage(
					width: 40,
					height: 52,
					data: 'eJzF0+EOgCAIBGDe/6WtLadGJxyTBv+ST9Htaq205C7Wmbb3ZKlTB4t1mqr1rQVrkPpzctxsua63PyOQQzOqHGPtV8fdtFUu8mYbi6r0M9l7Om7gbMfQ7AAFgvZTIEMBijq4B2QCnm+4l3XcWIebQe4PHZy/ccDamVUnEf/e83EBG0yNuQ=='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzd1d0KwCAIBlDf/6UdjC6c/0pCy7voSH1tFOKfCgDS8K003K2BVxqadD9UsBuqrwNIdYaWdOEDl9Ldo90eUOozPaK1KGvMdBBcW8IOvma8HqrlEig1tDTbvtUqtJtcOyCi567DW3SIW7dYEpf0wGGkfycB9zxVh72AASQ6ZA9zeXnb'
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJyt0lsOgCAMRNHZ/6bH+Igw7dWQKF/0BKG1tb8tkanHKrjHUqruRTb0igLvYNJXw52dJw0YJbR6yazyQa2ZcMWeblw1fKQp4svRv7Mk43SWcOobGfY3Rq9enXNUX6ZdmUwnZtYay4Ct3FrxKdCo9l+O2jetadlD'
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJy1090OgCAIBWDe/6VPY+U8/A2t5Eq+WQJT4I+QXMW7ggRWEPFe6ohcyUduee5ip293luYnfIxjU1M2nVzRaTL4OLNQnPNTulnc116Odrhc9IsOn1Wu1d2x97nR6rLGHTOxFY/M9yEUnRaPlzzORp8vEN3b7cAFQTZP2w=='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJytklEOwCAIQ3v/S3cfE2UWsybCh4nPAiVINgYKpAzCAGGK4KBC5CV6Hirz5Yze3LTMdrAXj0dEhClkthLmLSUga4f0U3OVJhg52dns+8fiPKzhilHZjkxmdlVUbEuRJer8uw+1ltpC'
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJy100EKwCAMRNF//0unUKs1OoFoq9DNG4yDWLMDC4lCYVZIq0Ji3Jz4y/bRbp1xReXYuNU5LUGNaasVx+mTlY8uwSde8bO7MyKtN+T07TSqWd9U3uspHTF+MZ9UNlBIjImJq+dkdqf/oQvmtFXV'
				),
				_LetterImage(
					width: 47,
					height: 53,
					data: 'eJzV1UsOgDAIBFDuf2l0ZRgkwLQhWnYkr0A/UdUDQxh7B2O7XJ5gbK0JK0N2svRiXWbg0hresco9DJqvzE0eyR85LPIVHIceNpGIm5GwoWQ8SqwOV/mWrl0nYMd4wSmH2fJToLmZySUpfycZD2KHl5r6ZCu+nY/52i5bxRlOWOZqpuzRP5vaXZrtyoo='
				),
				_LetterImage(
					width: 52,
					height: 58,
					data: 'eJzd1VEOgCAMA1Duf2mMP7rCwHYLRN3fkj6HCwm1/qOKmj9LF4tNuUsGFEnlGaHmI0Y+1PI1oaCAMWw+aRQSMdHfD+34CwZp/6XWNOOgLb7BcaYF6xu/nRHOjHB3ZKspA+OuBflfHRo86+NWg8aGsB1cFhNy27nxK28ooj9bSUODXSazMXqMalL5FW+9fh3fuKbdbz2XPQAc10Ew'
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzN1UkOgCAQRNG6/6VxYWSIFPxGSOytz6YHoin9MSRRB6RyQDaUjEkLDlY37KLICXsoYEckLRP3HZBpQYaOx7usE/fe6UhTzH1slrOy9Q6zu0/S1CDnzRzK07bDrvSj87M4fyV2yZWkMOeUhST+FGxuHK6dsfYSWRe6a3AreHmj/+UFfYfUcg=='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzV1UsOwCAIBFDuf2najR+i4gxK0rL1gWBJqvr9kDcICmppcVWLDZwSRS9VtdaXB3pPqwcpp3O+c7bWqKZbobbE3DBN5PR8tZeDlIarBsYeGqpjQ+27N8g6pzuPadOPTVTnfcQm7t+nS0T1cMOvdLg4XhuRzadooueU3xuxfvyqYjpe15dG72nhy8MHYXH3XQ=='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzN0kEOgDAIRFHuf+lqdKHIp0yjJLKEJxbaMfrDdLmHLit81O2KspuVGGCiXW2Kn4XUUlaXA5f2Wp4lHilADFnqPfX/z66QpX6ADtk01Ir81v5lr7oUtD790v/7xo/ZTAYNnyd7giRLej5Fz1slX755Pb9OwyAZjlEs33UT35LPbd9YrZk='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzNlFEOwCAIQ7n/pdnPkjmBQh0u8gmvqIWo+mOIcLQQArmjwD1wKqBpGxQcKl7lVGBqSODnd9IajAt6AJ5p4SAomuu9Qld5ZAugucucQ1dxuC6IXhA003rkmLYb39x5UBTpLhOTP/ob7RwZ++KlI9pf0bz3WIQDkkmBx8nRVpDQ0Qkhbc0gNnZKXw/RyIw='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJz7/x8EGHCD/3AwBBVh1YMORhXRW9HgdRnxzmdAB0NFEXb1Q0sRmtJRRQOjiAE3wKKH1ooAm0saHw=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJzty0EKADAIA0H//+kUehGq5ljQuOdZ4GY0eGKwOkML28PE68DI6dQBVpMOfPnCKdBo6fkPHiG5B0A='
				),
				_LetterImage(
					width: 37,
					height: 58,
					data: 'eJzd1UsOgDAIBFDuf+lqYrSUMgz9bOrsjC8IIbWlHBa5kyARkpoFJG2ooBU44a0ilKgyiqB4UQSSaH1Lf0I+FRv1agcy/nnQCE7S1au+RUgqhMt9E6SQbszpcQb503Z7qmjgDJ2MIrPtD7ERsa5zyw0RA2KT+MzktUFBg6Ao9Ea+AIIWqpw='
				),
				_LetterImage(
					width: 41,
					height: 64,
					data: 'eJzl1csSgCAIBVD+/6epFo4EXiS1oQdbj+RlnGR+f9FRMbUMkqhpSLoiKNQIfTIIR7qhkGPQQxX21Hp4U9wvQsjJllxMgXZTyVChN4dGY7GJdWPIh6B7gH3pKjxFasbTEM7BDArFm4f6AL+EHZf230x4hvVVfMzrmv8Me6hAX2xJauNx'
				),
				_LetterImage(
					width: 51,
					height: 57,
					data: 'eJzN1UsOwCAIBFDvf2m6qDYVGcTxE9lVeMUSY0Uuj0SQNwgSYaUm6VhOYBDEhka+52AKs5XESG4iqiROvjrQHxGn+7VkQAUHN0mEIDUcIBM3DUFGEDEEfbJjkEBUHw2D5M/2krm/DkHC7AypXZxMDU6thrZWuUPE+0J71u74u6SFINMY+D53C6VkNUGsQyCUDjFYXnSJgvn5ASdZpL4='
				),
				_LetterImage(
					width: 55,
					height: 62,
					data: 'eJzV1dEOgCAIBVD+/6ftoeVC4QqITu+jcEpHs1JuCgXZmyAz2tpFXc5iKEGmYLFjjEENyXwm1RezpsvHaq+6EcDQ/u2M2SuYk9rnkMFKkHHsZJP3ZZB55d5BkJQwXcgEbGfM7mEJP+cg88grGLc+Nj2Hbt3GWryZ4TOT4gbTsTABq7Xe/evokQAfxYAdMh1bP2n5Ld7b/Vt4AHaRAn0='
				),
				_LetterImage(
					width: 44,
					height: 57,
					data: 'eJzV1N0OgCAIBWDf/6Vprjn/Dh5QK+Ou+ABnmsg/I8TwWOJTOpSxySrhsR3vUoMC+Fbhy7ZLbbVF1mITAcOwxdNOsEZPd+MFWxScYG26OkikIrTxWG/PurnNFSfYiS/zmRXfkmXCeq835ctWqYQHVJk0trXnNqeUFqhgk1UWo1rcn12StqPxZ3E/XaJMuJw='
				),
				_LetterImage(
					width: 48,
					height: 62,
					data: 'eJzd1tsOhCAMRVH+/6cxJl4q7YHTioL2bWRtcZyMMeefTFrH69vNIdJlhno4Xm80erEegeMw6eT14hNeAtbvytwWeXSZnD+j2byjYW7rm15Gs/nQTWWqmz7U9PZlRHlRzeaDP/cXvWxYH/8PuZ/GXNLJwzzZAdyy5cuI8mIRnsiOhnr0RWoeRFm8u6HRJ+Yfj9vHBRxi828='
				),
				_LetterImage(
					width: 51,
					height: 58,
					data: 'eJzt1kEOgDAIBED+/2n00gNlFRaqMbEcdUcKMUbV/5WcxaUlS8TWA0R8UWE2viZcJWyHNonDlmTzPOFGcGNvUiCRnAloNj9gNcEDjiuOxDu56Ha3k3EzkIagboqINIibCUyo8HxFEu0Rr9wQ1yxTm5Ci8cEmxCuEGpx6Hz/0d1Eg/PPZ41gShw3JRA84IdiK'
				),
				_LetterImage(
					width: 55,
					height: 64,
					data: 'eJzt1cEOgDAIA1D+/6cxxmhE6kYZMx7GUX0r9jLVNfuICA2OmczEzjwmYGjQNjRIslxOYrMiFgKWEeRTxhfhC1yskvW1YzDUHfMv9tLU9cizRno/9saQPl/3dQnDyypkMsp8NegYtdyyfsOOwXT+nksyvOtiRSyqBu8xUuUY/1M5xhcvYGjQNjT4luVyEps9WQgYFvx6AzxWaBc='
				),
			],
		},
	),
	"T": _Letter(
		adjustment: 4.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 24,
					height: 36,
					data: 'eJxjYBja4D8UoPNHxUfFB4M4ALjWvlA='
				),
				_LetterImage(
					width: 24,
					height: 42,
					data: 'eJzt00EKACAIRNF//0sbBFHoL4i2zfItRAeM0OCKOD2u2UGcNa7DKXHlQn3yZo1Hr73kG6afevz+3TxrfdkG5lhOzg=='
				),
				_LetterImage(
					width: 34,
					height: 41,
					data: 'eJztzsEKACAIA1D//6cNhMhMnUSXwN0cjyERg5AEiwyRCha+suJEjjAqEBuKTW2pMvXi6VvBWKgzFrNJhbRQcIsWnwnGYindDHUsLf0='
				),
				_LetterImage(
					width: 29,
					height: 41,
					data: 'eJzt1DsKADAIA9Dc/9ItQov9xAy2o5nUtwiCQIsDi8TI4ZF4OyD4xM0Jrs750fOrfUWvOY42RJsoZCcoLEyi/h3Tve1IAsFb'
				),
				_LetterImage(
					width: 34,
					height: 42,
					data: 'eJztkTEOACAIA/n/pzGaqEFocXCTjtwlQKqaRDjtSTA2ZIfTyBAXTo0R42VAPAROGU/W39//2oBdxG9ZI1p4tlVGGZ8aAE/Djxt+H03d'
				),
				_LetterImage(
					width: 26,
					height: 40,
					data: 'eJxjYBgp4D8MYIqMyozKjMqAAQAlZA0Q'
				),
				_LetterImage(
					width: 26,
					height: 46,
					data: 'eJzt1MEKACAMAlD//6cXBEVLDYLoNI++BdGgCBM4sAJIQY/rWQAlSHH9lL0eInocejd+J+6uT2QZSZIO04pI+EFLSv4J9eI/aXykt2U='
				),
				_LetterImage(
					width: 37,
					height: 45,
					data: 'eJzt1DsKACAMRMG9/6UVBD/RmKyiXbbzMaQUQHIHEsGFaKOQAbGMQopT0Sz36M69OHiIDPYfidceDcFEtXmodAalQIEC3SDyV+9QpAyMYdJY'
				),
				_LetterImage(
					width: 32,
					height: 45,
					data: 'eJztykEKACAIRNG5/6WNIEEtnTYRRO7G9wFIdeBeJtBjnjQIxzwWs/tk6b45mmx7klxxM1Ifu/L+Ii7fv7/iwlwTsxvu4Hez'
				),
				_LetterImage(
					width: 37,
					height: 46,
					data: 'eJzt0EsKACAIBFDvf2kjgspfI0S0cbY+FWXGoYTBiHqwOCJaQfUAaWGQAyQKwIYOYhgIEuIe4aPla14g2eAhM1UjdzVHKVSo0EcUiomcQgMEB/Y0'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 14,
					height: 44,
					data: 'eJzl0iEOADAMw0D//9MZGZgrFa2sYUcjk3dgYWFhYWHNE/FLsWLFag9YqlJGyeZ+eQB/+Wuj'
				),
				_LetterImage(
					width: 14,
					height: 44,
					data: 'eJzlz6EOACAAAtH7/5/G4ia3adEoiRcIJMcgICAgICAg8AyEC6WVVr9Z4/3T75VWWrMMni9row=='
				),
				_LetterImage(
					width: 39,
					height: 45,
					data: 'eJzt0zsKwDAMA1Dd/9IKZKsi16KUDCFa/fBnMJkEEULPMJOYhgE9wyMR8kyNY8asKkGfG/02LEPCKrSNMWHa2jGzwcL8osKqe1jmssvOYLVihOQb35mvDH9+NQQ='
				),
				_LetterImage(
					width: 34,
					height: 42,
					data: 'eJzlj0sKACAIROf+lzZoUeT4WSQh5NL3cBwRc2CvN0doYE7GfQUIDRyTcVIIK8PiKOSWkVbgmhVH1j6OOV02dB4p9NGF8SimzSPf9m3zSEGMHyKEBzdwwGo='
				),
				_LetterImage(
					width: 34,
					height: 41,
					data: 'eJzN1MEKACAIA9D9/0/bxYJYtiALdyp5mF4y6wFMBBAGHi1iAyiDORIsDAtGL03CxBlLh2IcY+DXTQsvSEGRIqFFkUeqjfHlkSK7Xoxx8NN1Q+UGRwKfiw=='
				),
				_LetterImage(
					width: 29,
					height: 43,
					data: 'eJxjYBgF+MF/OMAmNio5KjkqOWglAYWMcKw='
				),
				_LetterImage(
					width: 29,
					height: 50,
					data: 'eJzt0TEKADAIA8D8/9N2sAVRI1i61YyeoqAIDwqrECAITUEJwoRLAxHC5WAqapz4zA0W9z9F29ZAt8Bi2B5+PDj4KSay0ZUWuCpH4w=='
				),
				_LetterImage(
					width: 41,
					height: 49,
					data: 'eJztzEsKACAMQ8Hc/9IVFMT6TVVcSLN8HQpAqMEA42i4tNCj4Vj3YNeewlbPYI0t9ubnHTi3T6HQUJVrMEcCpgsLxaFDh79DoWGpdQy6i6KW'
				),
				_LetterImage(
					width: 35,
					height: 49,
					data: 'eJztyksKADAIQ8Hc/9KWLipisaYf6Ma3SxgAkgSKIGHQCBIy+Agyq0PiVEAcWyiSMWqLhOo3seuOjCch/cyJFClS5DERgqiyTwPlGxgh'
				),
				_LetterImage(
					width: 41,
					height: 50,
					data: 'eJzt0DsOACAIA1Duf2lMdJDwswbd6MojacqMhUAHQZrB1AGSDGJCaFUBukbDGEmYq+UQg6pXENxDLfcV6rcidIoYGDXmJA0bNmx4ATO0oXsaOKfIcA=='
				),
				_LetterImage(
					width: 15,
					height: 48,
					data: 'eJzt0jEKACAMQ9F//0vHxUE+KC10tNsjWxrIeZiIiIiIiIi3vOtizBAjRoz4aOyzRI/P29wfWEESt1c='
				),
				_LetterImage(
					width: 17,
					height: 53,
					data: 'eJzt0zEKACAMBMH9/6fPSlAWNY1gYcrhQopwkHkwIECAYKQVIECwyTjkrYoUrl+ECHKGCPLhJXArXJz++QbDyBgF'
				),
				_LetterImage(
					width: 15,
					height: 48,
					data: 'eJztzysOACAAw9De/9LFYBoMH8vUXjIz3Q8VFRUVFRUVp9qaEtzS0NBwvf75RkPDWQbZhLlV'
				),
				_LetterImage(
					width: 17,
					height: 53,
					data: 'eJzt0DEOABAQBdG5/6W/hoSJSIhCQbM7r1vJ7sONG/cSYAQECBC4DRw3ysvQn17nGiKYft+HdyAZIYK2FUdQGAU='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt1DkKwDAMRNG5/6UVSGW0+YNN0mg6oWdGlc1ohCWnEqN6Q92eagl1LZUPdTnNWCox5PSw+3Yvh57W7hfqxxs0vkxpXhJpeY+nzeldhg4d+gFtpWEYfpAdrXYP6jkzFA=='
				),
				_LetterImage(
					width: 47,
					height: 54,
					data: 'eJzt1MEKACAIA9D9/0/boUtkLgd2CNzVR6wIzZRA0hoH0hwzik1xrFFsLd8t4wcb8TMNtIClc4tqPGosYsep/Yvffuw+y/KgXAEnV/ecvpTxNG/evLnfmQK/WfNLMMPj8QBa5gxJ'
				),
				_LetterImage(
					width: 37,
					height: 46,
					data: 'eJzN1TsSABAMBNC9/6VDpZCPDYOk5I0sKYh4BXcnhdBrLRYIowjiIExFEK0MMSObIEeIQw4Qc/G998mieLJjOUaqsaF0ulMUpyqN/vV7MxpufrVDFUp+oV/UzfgyGl+Sfbs='
				),
				_LetterImage(
					width: 41,
					height: 50,
					data: 'eJzl1EsKwCAMBNC5/6XTRaH4GTvBQbQ02zxNDGrEOPCSm4FAAuKOJBMUVeSUDTtFJVUdHKnGmartzoTZmTjjm4LlGgtGkVGQ9UvpQriz9k9P840m1T0/AoonRrc8eObraovC1bf1xAXNG2Xh'
				),
				_LetterImage(
					width: 37,
					height: 45,
					data: 'eJzN08sKACEMQ9H8/093No6LIdbrA52sVA4lFIyokRTdUNRleoNQxiTA9A0xjjlkHGQNx9gUsoygbYNSVM+pKfd8UHkhyIQgMucw+l+lbdseRIu1D/e+taXVSmzf7V8dD/bXXds='
				),
				_LetterImage(
					width: 41,
					height: 49,
					data: 'eJzl00EOwCAIRFHuf2m6qzSCfJU0bZyd8QWRqKqJiLJMQETlDoYJlWcwjC2FvQusD7dtAV2HkaWwvGACzWID9scFBd2+MBx3iP9DTcEjW/zVXcaMQ3pwOfzCEF9/EHyKzXpbF8UFQwQ='
				),
				_LetterImage(
					width: 32,
					height: 47,
					data: 'eJxjYBgFtAT/kQAO4VH5UflR+VF5msgDAIyS8Ss='
				),
				_LetterImage(
					width: 35,
					height: 52,
					data: 'eJxjYBgFwwD8RwY4JUaVjCoZVTKqZFQJUUoAIBB9rQ=='
				),
				_LetterImage(
					width: 32,
					height: 55,
					data: 'eJzt0jsOACAIA9De/9I4GH8INcTEONDRp9IBERpwvnTAd9RwNR1zKEZd4+yGDXewP+fO9O7nQ+2Xvt4N+jYr5EZXvRbp6el/uGnN9VkBFHj+LA=='
				),
				_LetterImage(
					width: 35,
					height: 60,
					data: 'eJztzzkSACAIA8D8/9PY6CgC4kFhQUqyI0jkBa4IIcCKoMYFBgHLDYHIMZE9I2o9ELPvj3hk0SNmw8Y/viWTvyFy6zFRbyc9SZIkSfJEjLoROS3JH8J2'
				),
				_LetterImage(
					width: 45,
					height: 54,
					data: 'eJzt1jEKACEMRNG5/6W1EMSYGDOgaJF0xvdBtloAKNHBVYxogXEovAsU9gobL4JD2Cg2WBYUDgbc43Vx9D3Up3yF56OP5e4t7usgbncMVpM4ceLE/2DuB0QU07oCAUukog=='
				),
				_LetterImage(
					width: 49,
					height: 59,
					data: 'eJzt1cEKwCAMA9D8/0/Pg4NBVdIMFYXk2PCgPRUAHiXYAmpkkERosh4QNgJDNBV0GQdBySCPflzTYSuWkze7EcQBB2F6DPiKPHhrFbQxMDAwMDgA0J/GWCwKQKqdtw=='
				),
				_LetterImage(
					width: 38,
					height: 54,
					data: 'eJztykEKACAMA8H8/9OKB5WWaiOKiHRvCQMAyQ2HlS/R49SEamVDQxlwR2k4VIJy6qAk4bKayIeUmPdUvXxVXkrpQoUK9adKnGpQXBk85ANE'
				),
				_LetterImage(
					width: 42,
					height: 59,
					data: 'eJztykEKACAMA8H8/9OKF2mpllQRUZrjZgCgUMMhCYpDjJc+35BTPZRDvC+t9qTmvKR0jAfwmvT1D1KHK7JXTraDlmYpU6ZM+a4svBRaxwr6Texa'
				),
				_LetterImage(
					width: 45,
					height: 55,
					data: 'eJzt0UcOACAIBED+/2lMvBhCW2K5yF4dCYUZDxXsHUwzuMwxiaAuwAbcx47TOIICZ1AURjFcFIClVmGMr1Vd4RFWn49gs61d7A/McRo3btz4L5zAhZ3HAZdZ0HY='
				),
				_LetterImage(
					width: 49,
					height: 60,
					data: 'eJzt0UEKwCAMBdHc/9J24aapSc1ACgV/ts5T0THYGOw/BTaH1SVgfkDaDMK4CaRpBDaxB4XYHwAA2rsW45sjwF59/ajfg2CHRpDcsQW8vsITLCMgICAgcBrYtneQrl9QcsiM'
				),
			],
		},
	),
	"V": _Letter(
		adjustment: 2,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ2Myo3KDZQcPjat5NDd9h8N0EIOJo9NnJpyAEZj7iA='
				),
				_LetterImage(
					width: 28,
					height: 41,
					data: 'eJzt08EKACAIA9D9/09bBJHkVnkIOuRtPJKMNJMFCbUkCMN9g7Tp/LDYG1N9e9bo3+g5aVDm85m5TGbx99ib65t/IxPUFoUCmSvaYv8tZwVGmnqi'
				),
				_LetterImage(
					width: 38,
					height: 41,
					data: 'eJzt1FEKwCAMA9Dc/9IdyBi2TduM/Qy2/lmfGAUFTCis0tQkIbFXqa3Tqqs7qjUjKfzqS2obtMqqR/lERVgq51JXUzGcP3xeyy807xAS1DliziIt3YvD8xCD4+C2MvcvNWoopg68pFfT'
				),
				_LetterImage(
					width: 33,
					height: 40,
					data: 'eJzt1EsKACAIBUDvf+ki+qjkU6IWBblSmygMIkp+UIkQeOhiwDUEveeC0o4AffAQGDkGrdwH2thAkFUwWj0LgTUfLnkNnKo2hwBMp77ABI59BupqAIjI4XzNTw=='
				),
				_LetterImage(
					width: 38,
					height: 41,
					data: 'eJzt1DEOACAIA0D+/2mMg4nSUoiTg4zktEqM7o2yWsyqRaHMnlCwABTd9lBpuNH66qu+Uo9761YKwmmeUrF5o0I3HQocPFfkBDFWTwaKz0+b9ZFIwnK1ItcTG7YUdAeigFjS'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR2MSo9Kj0rjkEZVi8EZcGlMr/xHBzSVhqvBLkMLaQD25Gi0'
				),
				_LetterImage(
					width: 31,
					height: 45,
					data: 'eJzt1DEOACAIA8D+/9PVEbRtwuIkI2dKZIBMhaiRsSuZZ7xkJL5iCqspOOvzZzBwS5kwPLfOgGtHvE3c8/R6FNcJ/ptXTGV6JWi3K7chOZ8yznkBVYsVFg=='
				),
				_LetterImage(
					width: 42,
					height: 45,
					data: 'eJzt1M0KACEIBOB5/5c2CLYMm5yWWPaQp9Qv+jkIwLTAjoSm4UKXa/pn6WupbHVJ1p4sceWV38shzaTxSXJABrySo53UdenqPTkhjdyHyThcjMre9Tvp97FzCX5elltmXsq6UmUec1kAzkABOA=='
				),
				_LetterImage(
					width: 36,
					height: 44,
					data: 'eJzt1EEKACAIBMD9/6eLoFKsTQlP0Z7KhpIOAiheEDMuw8wLRionM6qeaQcBg2++YUY2R9P3WcY6ZrS6MVIbyyyjs7xvWmE9misihv5t73pjkuda0VOMG50KLARuvA=='
				),
				_LetterImage(
					width: 42,
					height: 45,
					data: 'eJzt1MEOwCAIA1D+/6cxuyxIKTSetkSO+tAmGtzFMhWK0p7S1Cwt1HckthWSXJBkE8VYXXnlX6VLEs8nskhC7h4kLJ/LNAFC96GMW12cIlWSybfjh74vk7kB3Ts5J1aHGOX+f6SDZYnrC7zrAjc='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 42,
					data: 'eJzV0jEKADEIBdG5/6X/brFko0MgXYiVvkJUJD3A0g3RMcGC5c0l3CixxJI9wfLZyCxZCJZ5gTF87ViXnGodIikSS4r0R/7LB1Hsr18='
				),
				_LetterImage(
					width: 18,
					height: 43,
					data: 'eJzd0kEKgDAMBdG5/6W/YJWm04K66cKsmkdCSUjyGDiHCZhguyAphU2w8E+JJV+lb/CS+zVKLMOyJSyldHsaaqMmTpF3V3L+oOhyAGJ0wU0='
				),
				_LetterImage(
					width: 43,
					height: 44,
					data: 'eJzt1csOgDAIRFH+/6eri8bWMrfMypgoS3oEgq/W3AjXneE6h8YVNqxofIuKyyTVHTLFYRa6mzsofvpyWrxntyOLihaP0OUAac4TFcmCQp++vDlPI/X7YdG5tke3O4EnKK1Z18aPWa5NUtRGOmrLNQk6hvF+fQgPMQBE9A=='
				),
				_LetterImage(
					width: 38,
					height: 41,
					data: 'eJzVlFESgCAIRLn/pa2xNLW3imUf8Sc8dwFnDEGG6VJG9nAgQ8wWUj5HKWYOCs4tRdotJcWrrI/iqSW1wvJNY5/uYrKxn+3CQfVaQAobU5kyqe8RpSyPAq3muppqBN0p/JlOr4ThW5CgxEoZKdVZwUMqDjKmsuA8tQG6pOFJ'
				),
				_LetterImage(
					width: 38,
					height: 40,
					data: 'eJzNlOEKACEIg/f+L+3RwYWlu0Qy8k+wPucKSuQrQAKFViFoCVZQZQPnJkYNAoe0+E8hRflhCwcmYh0feOk9WDVi1bWdlFbcE7GoGUpHexcCDRSYlaXm1yjGonesIPZjaIBT2386J7Jj5e48tPa9bQ=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAAROMqhhVMapiqKhAU4+NO5hUYPPef0wwWFQglOGSpKUKAF18yVM='
				),
				_LetterImage(
					width: 34,
					height: 49,
					data: 'eJzt0MEOwCAIA9D+/0/jDktmUYokmuwgR3yWgFlSyEAm8JR+lQK/Fd56Mab1Yj4PY11xxRFhWnDYfgEpuFcUL+MfFfG1eeiSoFFy+UkaCVNgSYj7R5cMhF80DKqKBiHeoYk='
				),
				_LetterImage(
					width: 46,
					height: 49,
					data: 'eJzt1cEKwDAIA1D//6cdrINp0ZDQHUapp1ZfwJ5qZs6XqfouTXMRk/i2OnUZ/U5YPcaStqOP3lnnO6FD7z+6CGA9B8qJpovtx/Er7f1bev10E0M6gMiABiv0AYc/sKbnAHALehwVTVWnLwzF1WM='
				),
				_LetterImage(
					width: 40,
					height: 48,
					data: 'eJzt1FEKwCAMA9Dc/9LKYFrbQQxU8WPmz/QhCiKAogS6g2Jh+b0bu4nrA8U9M9HhuutOuuKfN3OtOuU+ljgnE85qW6x2oO6tRkGOHXdSXUwUWbftYw93ZM6lArQFIRg='
				),
				_LetterImage(
					width: 46,
					height: 49,
					data: 'eJzt1EEOgDAIRFHuf2lMXKn9U4boysCWR5ka08xGRQf7Os7ypaXjWr/QNItabnrqfa7QNXr0aFOnq2nRRxovIVPXGhovNbT4gK6GtTLcXYurLEPVQ7r5d7Reh8i2NQRiqeI7OvnblRtamjoHefzSZg=='
				),
				_LetterImage(
					width: 20,
					height: 46,
					data: 'eJzd0zEOwDAIBMH9/6cvKWLZgS3sLoorPAXokIC0h1pH6IrgR4xdw+z+iPFne2IXi1n2DbOhszTLmWH2SjpTlnF1I6vI5pJiMUuxdmhLpwvEuhgF'
				),
				_LetterImage(
					width: 22,
					height: 50,
					data: 'eJzt1LEKgDAMRdH7/z/9FKQYwy3t4CKYKTlDhhdaiBQTNQZzMP+OXu2u4npOqvw6Rte45hXFdXjpXcvqbcW1xVIiaSoRPmyh1ZOu/b3fV2gq/0JdeAAOhGS4'
				),
				_LetterImage(
					width: 20,
					height: 47,
					data: 'eJzl00EKACEMQ9Hc/9Jx49DYPyC4EnRVHlVMRft4iSKYaLrSBMvuaYJJz5tpPrNZp31lN9O8seVRMwqtDql8aev+PiCn9dS4ZXX+/Z+0Ab1hLe8='
				),
				_LetterImage(
					width: 22,
					height: 52,
					data: 'eJzt1EEKwCAMRNF//0uPq0jSjGDRTaGu4gtRI6h0OHCGUYzCZzUlp5aSUIzCr1dUTnVdY1J0xl1ltPSiKNxQlvrYoF9TOnNuMa+iDX35SBYfQNEBuRGHlQ=='
				),
				_LetterImage(
					width: 47,
					height: 48,
					data: 'eJzt1UsOgDAIBFDuf2l0o5bCDJ3EuLEs5SUD9eeulEla4naWYle53aXYFW6be32P3+FotIqTTRLnixupzf/I+5clNpd5NdrHfG4xXnQIry73HAZeRxtaeD6d57UYH0R/WDGDcPiYuieOQsjHvArB2qf9Oj6ECH/okNHzJwPgAxZoFjE='
				),
				_LetterImage(
					width: 52,
					height: 53,
					data: 'eJzt1sEOgCAMA9D9/0+jB2MwLYUCixd2nc8VIpFS7Aqf+Cbucp93TFTli0QTx+w3jVc0jRjLjY6Kpr+8DWZoG485Bs3YEVw0JKo2fHk/GuwmGNrUhjfGjBj+NCGFCvx+F+nmG7G7M2ScNuJYFSgM0gEwz/sLzhkWUZt6nHnrijrpxO2u2b0AnfpEEQ=='
				),
				_LetterImage(
					width: 42,
					height: 45,
					data: 'eJzNlVEOwCAIQ7n/pd2WLHFi21UX4/yER4uYYCnqhMxOkHEeEwuHjQWk7y5Ec4CRfSkkiUkmaT9dYgVZQz4J5mHe6QtJn/i/jW6x3zNRk3xpiJCkURFrwrIak9z+zuHBzZA1DTlIkp3cGF4E8SbKgn2qScksrLnRFW9/RoVO0yIPOpSzhQ=='
				),
				_LetterImage(
					width: 46,
					height: 49,
					data: 'eJzN1UsOwCAIBFDvf2nbpD+tDAMTTWQJL0LVxlpJFAZUXc6IyytSeL7OTSJrgw8pR9spS6N2hvb7/UsrdZPM6cFblX20d31Snykfp6g3uis5HdrxZXtIp5ul8Q/kZvsC7Ei0O8pdhYeg6gYga2v8Sj0jfB7PAToQ369Klk7qYR5qhafynSoa8cWRPgBataWh'
				),
				_LetterImage(
					width: 42,
					height: 44,
					data: 'eJzNlFEOwCAIQ3v/S7OPZW5EKGgGW79MeREwpiK3AElqhUQKxtCnZENzw3BJbVFQ2SGJFlIcMrpy9kvJHzXPP3vzmO8tZHxX0qqOVJ6zJxl+mxyl60TjZ5N8KEN6MY1Jpx1zLCAVRMmysDe3MK90ageVa5Sk'
				),
				_LetterImage(
					width: 46,
					height: 48,
					data: 'eJzN1UEOgDAIBED+/2mMxgPFBZeIDVxqYEpKD1XVhIgWoqrPqFh2wx5N4JpuOzbYn2qffMNrgdGyWcfzE61RZaCOL4S5kUbtMegTj4hKEzUxpEkSrU1+jg4fgrBLv17Pfq8Z/qRtsBo8mY+hXFegkc1ffuda9f8/zeuDbh2WD+95fMo='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYVTSqaFTRqCJ6KcLQg5U/tBVhDxaMMBmkipCU4pamhyIA5uta0A=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwqnBU4ajCUYWjCgeDQiw6cYkMP4W4Qg0zwIafQmTleJXQVyEA2f8AOQ=='
				),
				_LetterImage(
					width: 37,
					height: 54,
					data: 'eJzt0jsSABAMBNC9/6VDoSA2QiYKM7bkkfiI+MGGyUKocYGH8AaafQyxygOy2gPJRx89hiQHqbr3EBykRiOoUbXsFHUTqn4uGjujx6X7WWiS7AU2kHn5dmNr1P2PVcKoAOZMc8U='
				),
				_LetterImage(
					width: 41,
					height: 59,
					data: 'eJzt0EEOwCAIBMD9/6dpT41doKLCpYEjDmZBJFYIumyIuyIGAYjfQ2vqBNo53vAjMOxq2LBhGpRcqELUw7HvQu7Xw4fz7B4c3zhMDeQdnTt4H/tQc8WWIAcw0BLUK82g6AtO/t2GF+hTRwA='
				),
				_LetterImage(
					width: 51,
					height: 54,
					data: 'eJzt1jEOwCAIBdB//0vToQ6goELQNCl/IshLxEkAIF9wjcDnIBMgO+Z3RPYPEnboIu+EnwwpUqRIKuk75wjvfpaoaklGZpwFiLpSq7MJKaSP+TjaEvmEzcgbzcliiZmi1fcoQJS9dxInrXaT7djkATzA6F4='
				),
				_LetterImage(
					width: 55,
					height: 59,
					data: 'eJzt1UsOgDAIBFDuf+m6kBj5SSGlxsjsCvMW7aYAACMe2M7OJFkIczbpmqUZW21gt3WUYSnHZJo1a/ZvJkbljMw/wQw6wxS5mPHPYZYZL4OnGjZUJmKxa8XqZYz0aN1l3p0ciuMKpkiv/y7DU4pF8sQOJbkCYQ=='
				),
				_LetterImage(
					width: 44,
					height: 53,
					data: 'eJzt1UEOQBEMBNC5/6WJxZeOfhSVWHR2Zl4kVgAgGYOL1uohE7ZnqXW2dbLasi5YhA0bVlsqDLaWL1jtx5b1sRWLON2y8LRfSapr/29csToa+djmj5hkx6b26WPLydC69UM='
				),
				_LetterImage(
					width: 48,
					height: 58,
					data: 'eJztzFsKgDAMRNG7/00rCtImxOJg4wMyX+30TAEWITzgEUaYlM/3ts/x7VXxGxA95cuX/6+3zTXf6q/5aDPb+8kk37/112xPgj9qBwf+7GPVB4ngm95PRvCm38+id1kB5xrzUw=='
				),
				_LetterImage(
					width: 51,
					height: 54,
					data: 'eJzt1cEOwCAIA1D+/6dd4snN0hWChy1wxUeKMXGMaFlYnCc2K3ZaJ3arHxM8oo6woDt53c1oNWnS5HtkG1BNcMxi4lwG20QisFdDYNedkyIwA0v7IMqCMgFU+HT4+6YEUQxyBAb0TpOdVLLmDFSa4N4FmWDnXw=='
				),
				_LetterImage(
					width: 55,
					height: 59,
					data: 'eJzt0zsSwCAIBFDuf2lSpEnIruj6mRRQqg8XZ3RXyiR1jNldAhlh9q5iKWN9VrN2asB6hrWkihUrVuwY+3bZw1jmLYy+UHuyboZ3f8CeGndcxeIRnD1jZOQJhnxciQ+cXdvHMGdIZyQsFzMshFWYgx82eKnGyPYFtswCYQ=='
				),
			],
		},
	),
	"W": _Letter(
		adjustment: 0,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ2Myg0NOWR6VI4yOXoBZLvR2bSQAwBtUU7A'
				),
				_LetterImage(
					width: 28,
					height: 44,
					data: 'eJzt08EKACAIA9D9/09bh6jUDULo5i4RL/NgmclAwowEYfhvkBbqj+W7EdJWtLUyQ1skdt6U3ftYxfqWzPUQ/cn8r9FT8+/m5X8zSV96ZwCVJi7u'
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJzt1MEKwCAMA9D8/09vkIHb2tQGD2MHe7N9VlEROIwAw1OdhMV+pR6ZqRrZVrFiKWz1hdJXnNXo2qn0ELZaVqxqpadkpXp7Ki4y32fdu1Tx3yxUOKnE4lN31Lsv657iUKsbXoMTZCjGVg=='
				),
				_LetterImage(
					width: 33,
					height: 43,
					data: 'eJzt1EsKACAIBNC5/6WNgn42o9CqRa3MXiH9AIsbaktBhB4Gsy9Bz4WgpjOAD67AeUQe9OiDe9BGCCDYg2PBFGB9LgLQ4t1MAXhF+xYoYONT0MDfR0uBLdeYmRYWgH5vrQ=='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJzt1bEKACAIBND7/582WiLz8hwaGrwp5GUQRmaFQIsZLYQCvlBhQ1C0rVPXw0HT6gcFrdYyUWHZ6qXiJmsQHrDcSztlQ1RSppWvcuWq1+FeVdvD1ZnzArjyDRNT+B8GBOrqMg=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR2MSo9Ko0ujMEalB7f0AABUh2BwaCoNAKyCulQ='
				),
				_LetterImage(
					width: 31,
					height: 48,
					data: 'eJzt1LEOABAMBND7/58uC6G9nkHC0k7ioSUNMxWQKhk9lOWMlwzF4ZiFWRb4KP7FY8AZxRcclG8ywdvEmUm6WMQF+2qyDbTntpfj7DvWX56tyZF8TDMaI8XBWw=='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzt0ksKwDAIBNC5/6UtGGjFT5zQFlqIO80zuhCAcIEVCU7DBC/n9MvS1lp51impb7TEln+UtqGT1/fPyuQmt3xPKqhk2XhP5piXdudWJkNc70xKqJQyXHuk4oKXbsAwvNS8lAaP7ABka0Tm'
				),
				_LetterImage(
					width: 36,
					height: 47,
					data: 'eJzt08EKACEIBND5/58u2shccp2hS7DkSZqneAlAYQXNUAarP5j5kpnxykwLBINrzhgoxtprzpkeRiYc2DMrU8y8LDXLWj+jmK/zXJCbHnLzWmnnMVP8d4rZ01eSmAQn'
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzt1cEKwCAMA9D8/09n7ORsTZbdZJiT6FOLUCTDIIWhxJ1MvUs8so/s2xZSXFCkKQUqR/5UIpJj7OVifOS2Ujp/DiPZ5z9JWZSrOpSMZF1QsjTb6CwjOUXKFrS3UbKe7J38OqZcrWVvuw=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzN0TEOACEIRNF//0uPayJZYBpjo1TkBYIg6gEu3TC6Jrjg8uUmvCq48KrEWfPRSyG5e0dw+WvTV4aoz1zvqyKdSuwpVVOLKQMRvqll'
				),
				_LetterImage(
					width: 18,
					height: 47,
					data: 'eJzV0jsOACEIRdG7/01j4Q+uhVNN4qv0SCRRIq7BeziAA34XJKmwCxbeESy8IGO9ZR5+l3wlNbnh+txSHRI9rYZI4lmrI7XLchraDqll'
				),
				_LetterImage(
					width: 43,
					height: 48,
					data: 'eJzt1cEOgCAMA9D9/09PL8pgLR0hnqSnhT1xGKPu1VjV3am6CrU3Zaio/YuCyyDFd8iUDjPQ2dzGcujX9KkVDbWguT50mYLvV6uHFqWsIebbpgDKMyZJumE9vsR4kwQRbeveh1JPoYfYp7VfXvfgJ27YW+QC3zv6MA=='
				),
				_LetterImage(
					width: 38,
					height: 44,
					data: 'eJy1lEESgDAIA/P/T6MedCokCIqcbN1JQg41kwP960L2KSCPGAapmqMUQ4EiZ08xbU9J8dttjeJbS2rC8kuwX7toBuuInR8pBUUZ1cq7CFTPshb/bbDxLiS1dgF4LFoiQqSLgLhgQoi6NCloivVAE0eE7hWZZHuPNR/nlBFZjtkAS7mhiQ=='
				),
				_LetterImage(
					width: 38,
					height: 43,
					data: 'eJy91FEOgDAIA1Duf2nMTNTBSpkY3JeS59osmarXEtGNJWNtoRR2qLZA/1GkzCBG85ArKSlctjGwUOv3QH4OUYB5tw9M5bUW9S2wXsudQ3/gy3M4R1GgdbFyDtaCuyG0KEEK7MH2wh09TNX9r0oU6pir554QaEYHw1V8rg=='
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAAROMqhhVMUhUoLFGVQwPFYMdoLkbG5cuKgCFNe4g'
				),
				_LetterImage(
					width: 34,
					height: 53,
					data: 'eJzt1bEOwCAIBND7/5+mjYMB5Y4ytU1kIvIEBhPNikAFKoE7dFUKfFasdhV7Ny/yeQ0Bb4/4sZgZEzjiTZEAdtO0iEdZh65gu/XFNjlb3lwqBH30D0WMcSpFaMTqxVd0AVa8Qug='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzt08EKwCAMA9D8/087WAV1rV2CeBF7s301BxFA4QuqfkvT3AokfqweuoxuE1bbeKPG1Vc3PWwRusshdfgBrj5Um5nrZDvWs7yd2saKDuO+N/zo4nuZ9s8S8QVdjaBdkjFNWyfR/UY9PlAzEyY='
				),
				_LetterImage(
					width: 40,
					height: 52,
					data: 'eJzt1MEKACEIBND5/5+eJYLMVts5eGrzZr4SQQJAJaA7KBYWv3fz2YcbBcW1WrHDdYe4eOciN5LrjnK9nLjsWuDCFtUO/o/audf7zm3mWlzYgBbVrpc1tzxugymupZmj2wjyAYVXlpQ='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzt0sEOwCAIA1D+/6dZsoNRLBSip43eSJ/oQdVCpILzWt7kZUrLnE9odBZq9yar43cd6DWtW1e1pPU0UI2G1j/TgaXrTONr1LiL9Vy7oXqpQr1VgbaVjhCta65pEAH/wdfbFZQOTdkDYcpC9g=='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzV00EKACEMQ9F//0tnHBBbTBYDbsZuio8uDFqQFdEcwZWAPzaSkWwcgnG1kazFv9B6K9M2DT34VyNZzUfrP2fZFmK9jZt0aPPGYU1l9doDaq0KEw=='
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzl1NEKgBEMhuH3/m8aJWz2/fUrJ3CCJ2S2QBKND1UMykH5OVqHfxWtZSaVNxSt9rUuVtcbTfMOXFWtKStqjprKs2sIbORWqU/wZm0xhM8lrhx3zFnoTc8='
				),
				_LetterImage(
					width: 20,
					height: 52,
					data: 'eJzd0jEOwCAMQ9F//0u7S6BJLAY6VfEEDxRARPocXDDDjV8aZnl3GGYwzdbbkzHIYpJtjS+t1D6bXaGsq5beTVesf5TeHMyaPc5TT6cH7ToMEQ=='
				),
				_LetterImage(
					width: 22,
					height: 56,
					data: 'eJzl0zEOACEIRNF//0tjBYGd2UobIx3PGEExYjNwhlGMwrXaFkvHllSMwsNaV9WVJzWzoZWc03k0GrO+NrSmEVF96V81U/FR8/OyoJBQXGesUMw='
				),
				_LetterImage(
					width: 47,
					height: 53,
					data: 'eJzt1UsKwCAMBNDc/9JpVyXfSSKFUsjsxCejIMo8CY30iNOdie1yejKxHU7L5zxanPCsK+Jga47jkxDI8r9xez8Al4OaR4PlX3L0LljsuzTPp+rtvsRDnPDEmqt9yNW8s61jsUxRzCaIW4t5lCNe/CCKyxJoXUmZCywIt4E='
				),
				_LetterImage(
					width: 52,
					height: 58,
					data: 'eJzt1ksOgCAMBNDe/9LVncjQzyQtiYbZIfNEDDGq0hGe8EbusH3GyBBeNBo5pt4YtzCNs+za+I+KJt5egUm9xmP+YgROo2/ewzZjDI/5gkl87rDQYNxZ92qTMYRpzP5DKsxUwX5+t6qxGWcVEhgEoVlns6H+HWU6L1Ef18t1L5eN0HY='
				),
				_LetterImage(
					width: 42,
					height: 48,
					data: 'eJzN0UsOgDAIBNC5/6XRmKgVZihtNZFVU558qlkWSLMTEnsUGSoWH8h696Sov1AyfkqlaOKlnCckvpD3VV2S9yjutCLlL/7voKNFr1NP+tOcdC/nTslKRC4Pmi2/Nujb72QViVYCkbLtwWBoI9iQfKykW/PJpqQYlE2RFW2uzAXrxxyXIo50jbaVe+6sTGMD6bpa3g=='
				),
				_LetterImage(
					width: 46,
					height: 53,
					data: 'eJzN1kkSgCAMBED//2m04KDZJhNwy4kKXXFQDraW1JaBWb0dxctRJfy1ruXGw00LaL/l6ehxyxqn01s1fWnWtPHezn80uj6lY05/oFf06l05l4Q2yyi5ns2c09U4Sk3Tx8QvxVwffEzdw1Ee1XFwrEdTLkAUi9LZxjdZYgPNXdJJZkYr72+H091Zfo5Ih/8Fd+iwuuC5eAJhQdBeO1AmVPI='
				),
				_LetterImage(
					width: 42,
					height: 47,
					data: 'eJzN1UsOgDAIBFDuf2lMXGCA4WNTsV2Z8aVTMUbmZxFxc72R1MIk61c5UA6CUOoohSouJY1IDmS1pc8/lQeVl2OXG1W5vdomWw8E5BHHNMFs+cqM7jApN3aTtBYOL94VQyBdhSsqpB5dBqO3iCXLl9aQ+NAt2fiVot4LWB8uCw=='
				),
				_LetterImage(
					width: 46,
					height: 52,
					data: 'eJzNllEOgDAIQ7n/pTHqxya0wCKa8bXAo4NqoqpTiOhCrNJnrLDVhh3pPwcB/SFtkxn8LPTT8prm+xekUWVDmhtScaSRtjDUWaHdbaFXNuWOOV3QVk7TTUK6YeyeJV0GSdMHAAdppIm1xG1bQtJ3Gswxv5riI6B9AzO7g74ACiPa3wUcz2lrbAIP5Btax5euRrOly3TpF4fMcACIDy8Y'
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYVTSqaFQRXBE6c1TRqCLyFA0tgOEPrHz6KgIAfXdvrQ=='
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwqnBU4ajC4aoQkz2qcFThoFY4YsB/zGDAJTJgCgFk0c9N'
				),
				_LetterImage(
					width: 37,
					height: 58,
					data: 'eJzt1cEKwCAMA9D+/09ng8EmsSGK7iA0pyLPUupBwCcGzC4UdyxwKM5Ave9Q1nQeqfHmUJNChV70lRpxWehElBl9HRbRWd7nN5RnAY0M0e4BELvjt1lElOfcIOqnif2yL+GLCi8='
				),
				_LetterImage(
					width: 41,
					height: 64,
					data: 'eJzt0EsOgDAIBFDuf2nsQk35OkHTNIZZkfJKaJmxEOi+hjSCGAIg/R56t95Afw8Jk4ULUKRhww3hVKfQ1g0b3nXAilC3IGhOw3FlGGUdNG8PoPgkvpJCnrIQ6pydZ6gHp8rZyOYAQHi9ew=='
				),
				_LetterImage(
					width: 51,
					height: 57,
					data: 'eJzt1sEOwCAIA9D+/09vB1kiUZC6jSwZ3NQ+61EAOLhBGgHnoGeDRMzviN6Pku7wbdISKWSYIkWSiLZB0lcSBEWKPE8k5xH/EpPY7LNEIjQxqsfvz5pMyxdEh7zn3idXjiSTUslukLbnE+1kfQIShANE'
				),
				_LetterImage(
					width: 55,
					height: 62,
					data: 'eJzt1jsSwCAIBFDuf2lTZJ2JRORTEM1AifuQypGIqPmL0tldQebCnBldsTBjRx72OE5iCKWydxUr9i/GB9jZcHkOEx+PYsU2Z4gqTJ0ks+UWRzCkQkzaYTbOxPgXYr1EY2Vc/lvWoxE2ux7xIENTZaPtjQvgDttr'
				),
				_LetterImage(
					width: 44,
					height: 57,
					data: 'eJzt1MsKQCEIBND5/5+eSwRde2izEVrozjwiRgQAFAOJVvWwUdaz06lgRynDtmqSRdmyF2t77vbPypbVbBeuDZqP1vEvWHjf89nugxYbXsxmnVG0kWW70O06xayr2pYHlvOTIz96Bzv9'
				),
				_LetterImage(
					width: 48,
					height: 62,
					data: 'eJzt0EEOwCAIBMD9/6dtbGgqtVA5oDZZbuDgJgBACRQmeASWoIo+3+v5mL9fM30FyR709Mu9WhzyTUtP/1cvyPHuD4Y3Y3fzJwj6t8in/zpZ783Momo3Lyjk+7gLRn2duL7dkfYAdD8bLA=='
				),
				_LetterImage(
					width: 51,
					height: 58,
					data: 'eJzt1VEKwCAMA9De/9IdDMac1ixhOkSav9K+Fr90V2OymE/sjDbNE3tkYxKv6BB0dQh5fdtnUidJktWJaaSsKBJWSZJMIhgwe5seJHEPXeis+4egMCT+ivFKhTRdv0MQrzKchLn6AgmuMeMFYUYP1ew4Dw=='
				),
				_LetterImage(
					width: 55,
					height: 64,
					data: 'eJztz1EOgDAIA1Duf+n6YaLZLAwQjSb0b1vf2IBMJKVeY7InQSJMxjRbMu2eama/mjDPZ2vYJc2aNbvPJMyGtZOp62bN/sxWqIzxUpRpx/YoFDM7D7Op4GCssGIgBYDtGgxzPsZ4jkqM0bFeczJnewMiIjAl'
				),
			],
		},
	),
	"X": _Letter(
		adjustment: -2.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJxjYICA/0iAAQ0MZTl8bFrLYXMbLeTQ5f+jAWrL0dt/yHxayxHj36EsBwDP8J5w'
				),
				_LetterImage(
					width: 28,
					height: 45,
					data: 'eJy101EOgCAMA9De/9LTxBBH1yKo7MvlscEUI2zAwhkWjGG/wRrV31R7t1ztOzA4y/mc1bVIsWYpp3VcKwfS9J/1Z7G1WO07Z0zwcl2Wjj59F7y4F87qQO1ZvYeBiY4P/4PozbHRFIWXiAMmB5uB'
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzN1EEKACEIBVDvf2kHhKFRv/qjWeQq7EUmlYgSIRacmqRQ7CrlMo3y2U6tmUlJs2mpcMFnygaMcpGToQn12tiq1Fq4V9GfAwXOgFQouVEAcIqo+1f1cTaMJScIl3OqeBhvglP5OOdqTQxK1SV7la8OVFHW6oJvcls1TcLyAWKKi58='
				),
				_LetterImage(
					width: 33,
					height: 45,
					data: 'eJzN1OEKwCAIBOB7/5feaKOc2Z3Mwcg/lXyiBAUcOtAiBQptDJ5nAlyOgZEWAKTLGkxN66CtGQAD8JzUeL0YK478BxBDMnBflwRJ/+/AyLWzbDSLsiro7RSYRy6DkRXAfTwcvHibMZCJHYARCjo6AdFrGxA='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzNklEOgDAIQ3f/S8+Y+MHoK2jUKH92D1rZ5jxRoyf26omGGuMXlDQIhWMXyJoHtYiYvYjSREJh7ouUqkKhWlDQlVWajQMBsRTfxbsUpGc2Un5itn2S6n80HyUKcq9CeNfigL5Eqcppb1JuNeG7WOApytqtvRz8OLLmXF9SBWRWlWsD2aeMng=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJxjYICC/yiAAR2MMGlUtRicwSON3S80lcZU8h8dDJQ0Tf1NrDQGZyClMdVi98twkwYAU0MLEg=='
				),
				_LetterImage(
					width: 31,
					height: 50,
					data: 'eJzF0lEOgDAIA9De/9JoYmKAdnUzZvInb2NAjHABq5ZxhrMxYyfDMZVJql5JGcfoTcwwxlwyCywuoMQLzpl+NrgEzbnMvKQvuXXuKuCH9mYXJ/D6A5r2o5WpkuYYc8kssJjz/ig7muR4Zno4XeCmL+7bDhlbWKucKsUBLn9K4A=='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzN1eEKgDAIBOB7/5cuCBqmpzvHiPkr9GubVgTg0gIdCU3DhC5rerJ0uVq6/ESa2laJ+qiVzJrdIp8rVX6DpcOA6hXCndn5sx67MqNrko6Ay9BvLanR5fJ8/pQWjwZNieNsEV3GD9gjXbImt0lTm8vxjsV9sifSl2SbtK03X8nG3+pkafFUDn0Dmq5e2g=='
				),
				_LetterImage(
					width: 36,
					height: 50,
					data: 'eJzd1EEOwCAIBMD9/6dtUpuisAiGQ025VHGweFAALQrkTMjwxh/MlHHNnPWNLJQN5nnG6B6L5v7GZgxtoEqosVvQHs1vjjTLcy2Mvp+JVj43ovpwyBNGa0umz2JjjlAzkl+aZ4WVmJ02TMu9LSz8Ts81/AX03AXUTtdT'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzN1VEOgCAMA9Dd/9IY/8bazmoIwufyGGUaHcNc4UJTxr089SwjrXMkbiNSHFBgE6XUTZmTKImZq5zLUkL5uyxzUzI3tiWtQF2cIjpTtkTCQ9stg91dbZhk2xoz/CsFjB7BW0cvXUv5q0jOEhm4FO8zzb9G6rlNlXbCthyvpApZOuQkVNLM/e/hHNlCOUlcFxksYNg='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 48,
					data: 'eJzF0kEOgCAMRNG5/6XHhUIn/YSoMZEVvFBKC3IfEqWbQF/JIpkpcUlR1MPGmZVuzB6IKNeozSlzsRRTzmo2Ma/EFEc1GUKZR2SVElpR3UADb0q8e2bDF6B4K39/3ANxg98v'
				),
				_LetterImage(
					width: 18,
					height: 49,
					data: 'eJy9kksSgDAIQ3P/S8eFGkJqp3ahbKBvIFM+5NKQb2AAGMB3ZPIbBLHMM6zaS7fksU0UyXu2iMrv2PSYhJ0gCZJghzAJF2SiZI1Zs3wiMZC205ck9u6T6l4HUEVR28B/58mwA1Qd8R0='
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzNlUEOgEAMAvv/T6MXjcqgJB6UI5luKYlRajUtt6rlGnR21eATOn9C70m1nHKjMIoob3E07LGk4UY/PtUBjb5AySf0ftuYLm7IdHg7xYcBJ2UL6Z5YzRnFGISGxFlv0DzQ9zB9D9P34DHsmYBasoSyU34L8HZC4dAeNUtC1CxdBXYgBWZEw55P/ja/Qh9ItdyGFtyqBQpoy20='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJy1lEkOgDAMA/v/TxcOqArxZFELuWFPHLqoc4Y1YmshdzWQEhsfUr2JYdhoUPDtIcr2ShheU5FitKTPiBX1GCm1nDysoKzhW2SDXAkDFDCUtU/RSEDh94k6WMO/K32ZlgpO3aciJbMziq+QanVYRUGfULw5XkRKJKXKcHmmmfLVow7f0v2swLwAPsciFw=='
				),
				_LetterImage(
					width: 38,
					height: 45,
					data: 'eJzV1EsKwDAIBNC5/6UtobREHeNsLNRNYXjGfKBmTwEmFFZJqIUTamxgbuKKu36vpULONLVlbGJS/VLr2yq4YgpR0W1FEe+VolSjigFNBaGoz08XmXs376tlXFAOq9SeacondGDdduw8DnzTnLTqDlPAHEX//MeKZ7R4YxcffB8a'
				),
				_LetterImage(
					width: 34,
					height: 43,
					data: 'eJxjYICB/6iAAROMqiBOBZp6bNzBqQKX/waLCmzK/mMCmqugj2+pqwIbd5CowKIep/9GVYAAAI69TNA='
				),
				_LetterImage(
					width: 34,
					height: 54,
					data: 'eJzN1OsKgDAIBWDf/6Ut2GBejspGI/1V+uXSIOYiqAKVoDfyaiqorbDWCt9NAnyeLV8R7iWU0LlNMVkkVqMrQqXAA6CRnS0QaIG/CDdL3mh+lBYDIUBVfQxg654bARqeC06Fzm0KuJ91pzf8qRDXSERjDOGOC/+b7UQEgmXIeACwh81d'
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzd1UsOgCAMBNDe/9KYCBEK09IREg2stH1DBH8ikuJDWH0PTsciQvFjdV+d6qEz1aod07KiQcDXzh5s1PmQ0d1Y16WqCnpFYJ5xUmf96BKcW/GNFk7nGqUNx+n48n6kVaCcdF0rYM/FafTdWdGpvXERjfdpt27bMf08y2+0DpgavzymRpGJJn/tx2oViOiauABF8TMU'
				),
				_LetterImage(
					width: 40,
					height: 54,
					data: 'eJzl1EkKwCAMBdB//0unlEoNZvqISIesYvIcFwIQJsA7MBY9fu+GWubGRupUr3KYcMYmzhx6lTsz0mGJayU9TKabacH17I7vcOFtGSf2W+FO9jCnact1x6XRChvdNeSc8wBrXG+VTmacooGb+k/dAAm/4jQt3I0Pwz6klA=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzd1dEOgCAIhWHf/6Vta10knB9w2lZxl3wKzpy9T0SbwXXdzqjLkm73+IVWc6XGShbHfQ2ZoRBr1daqNolAi8Si1impMbVZwwIiReWCEkBD7eh3tJtzZYoV5N1I+nmPRmy1AF7Dj+vGgqvPfW3VhXV4+4s6PINxLDuxB7X5Zi0KgYa20vfwFzrD9olL4gBjnzcQ'
				),
				_LetterImage(
					width: 20,
					height: 53,
					data: 'eJyt01EOwCAIA9De/9LsQyRFagaJ+7F7Lg4SBKw8kFYRqAqBr21pt8Ri3B+UIQJte6ZyIk4NykCdekoWbxMzZd74/LSmmbLV9GF2MyiL0zfyF2n1EuLXpc6+pVnLJdJs7NQ0+zM58PKqPbTrrfoA5Xdiug=='
				),
				_LetterImage(
					width: 22,
					height: 58,
					data: 'eJzF1FEOwCAIA9De/9L4MQ3tUkxIyMYXPNG56AaECRTqGHAOOP9Wq71FR+WtM1VFZtyxC95c5oMKrydkmirVXQ2vD3m1q85qntGrb4+42V7h9dTk+hxNEFLoTR1UvevUQipFRylqrf4B/+rts15NeL5e'
				),
				_LetterImage(
					width: 20,
					height: 54,
					data: 'eJy90lEKwCAMA9Dc/9IZiLSx6dj0Q7/koTFukscDLjCDGy7ZjyrSGGa6fM4lYp4KOR1nNng1pFEtU14sPS5Bs2X/WOAGN2wb3fhtTWJn+Zf0jkK9yXup9TdNy8e3DqsTeWGNSZzFLnLFvEktxwcI93ik'
				),
				_LetterImage(
					width: 22,
					height: 59,
					data: 'eJzN0lEOwCAIA9De/9IsmXG2UJIl+uG+8BERnBGbH5zBKIwCl6jt1usXVpU9cwHZNBbgVnBe30RWkIYoFWuVMuvYMKpVxlFOYbSMtKMpYZvrFP+V/r1cCGOn/CbrROdUhpwRj14ifuBW5fJq/WQ3qOu2WMQDQmvVRw=='
				),
				_LetterImage(
					width: 47,
					height: 55,
					data: 'eJzV1MsOgzAMRFH//0+nSFVJaO7YY9i0Xjon+IFgjE5ES7d4HNGxLo8zOtbh8bO81K2tLNzCKcccc/kI4LIiDCoXBTtM3gIdPebnJYOvNahuQGwHqsG1hjGPyfEW6BGfdRS87mlya4RrnybHGW7x7NYXr4rAfnK+1ahHeML34pLvyYSrnPg6MQc1Ek4t9Tgkr6vlH7aw88RILvtxnvE+gVyT69a1dTi+hX/kpR4NOrlnj3gBLmTPdw=='
				),
				_LetterImage(
					width: 52,
					height: 60,
					data: 'eJzl0cEOwzAIA1D+/6dZD+uaLrbBrbRIK8fAC4Rk2hE+8U1s4dY7JobwRdPEX5sWSRuk/5mlITdRI7pjI7rDBag9wi3r78LZleagPXNuh4cIGHNKTHxuB8UtQywkCYcnpviJyZB+wtAZ61hqCjqZRrsLK993vmYVaBJl0LE2/HSmhYHttMEj/sjA4/wOkqP1Q7J5/EkaV72T9CrXyOeI+rYh3/Vg0yLp1g+mD7Z4ARNHC1g='
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJy91UsSgDAIA1Duf2l041hKAhlRuwwPWh0/7tWysvpA2rlEZoq1D6S+ezF0D5jMrRCSTUgmSHpyWfJsTevuNVfkVevkXWyH9jIcIfeVZ6BuKKHDM6cSbw89vCQs5xf24y0QZawHyR+/NJ7JfJBG0lcKxNpQQcJuINmtyzGRIFYkbVY/j74HTKaly1f+QOOZtH4AcSUtGg=='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzF1usOgCAIhmHv/6atrbWmfC+Cw8VPeEJ0nXpfRFuBXd3uiMsnUrhe5ybZ1oKblKN1SmFaTmT99U5pNzvklz2GSlC/1Yj+6tg8pw1f6alsLzZhBnIsaLDU+w9Ng8M1cCikq47mpK44yIlM2rt3xTqo5VTVOvSI6s3wNhMaekjdZZa6RLV6C+MkuoNckfeu/gwcLeKkrvxUF/V2yAXqQAhN'
				),
				_LetterImage(
					width: 42,
					height: 50,
					data: 'eJzd1dsKgDAMA9D8/09XRFC6JlsG3vsiZGd2bgMjjgLCrBkJC2OvR+UNzdlUJZUVva6QYKkvU8y7Vyn2ronXpyWRS0gUqZZZVD0lAUm9TnLjyxa58iPbU2m+Ob1LREbEW22ZkC+bTDXvzR3NH/U+Blh2stxiEgks4G/+ThPfHuVAF1nHKR4='
				),
				_LetterImage(
					width: 46,
					height: 54,
					data: 'eJzNlVEOgCAMQ3f/S2MwJAzXwhrRsC/tXrsFTSjFlVkRSqVrKWzW8A+dgDV629rYz2k8kMPpFLqiRM9VrhtS6UxbJKCR9SlL27P20HdnDsewAQTfnsOoDqcZp9ERVOhjDkOkI97+GQfMHCiOp39Ijw2NDiJfZJ4wdrC+3sO3XtDOkKNbB2ncQOGDLvLt174WLZ5gN/T3C4IlAlM='
				),
				_LetterImage(
					width: 37,
					height: 47,
					data: 'eJxjYICD/+iAAQsYVUQXRRh6sPKHjSJ0MLgVYVf5HwsYZIqoFwQDpwgrf6gqwqoHT8CMKsKjCABc981P'
				),
				_LetterImage(
					width: 41,
					height: 52,
					data: 'eJxjYEAC/zEAA3YwqnBYK8SiE5fI8FaICYarQlzKMZQMBYVE+3rYKsQlMowUMuDQiT/YRhXSXiEARDxdzQ=='
				),
				_LetterImage(
					width: 37,
					height: 59,
					data: 'eJzV1eEOgCAIBOB7/5emVq2pdwSlzeKXsk8U29IsDiTMKIQ1QhAh/AOxJ6SKUqEQecc7swDtPB4hQE32Car7FYgv5R1UJ8WiFKKWNfCR/AKzEXcXltvG3zj9faQNEmRvm4lYQkjV7UXt/0l304X0zRVTa2MSKica+c0fiPa9ekG+jXyTerBtARyQl6E='
				),
				_LetterImage(
					width: 41,
					height: 65,
					data: 'eJzd1t0KgDAIBWDf/6UtGJRTj7gtqeZdh8/9RsScK0q6pyGdlTGUgLQ99LpWoL+O3gULvnOSVQ9lvg51Pg0vHkI57segjkGr6UcmhODyfwo1b4+JceE1TcOXDwkxBTFr7+EotDOB6W1UA50vrtOr8noIb6sL2FQh5CGIdtINIM/Fg85qXehtay8Ysfy/Fx/mso25'
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzl1UESgCAIBdB//0vbhqZAICC1mWRVyHOkMgGg5QLLCHIOPAokYrYjfT5CxGCB2Flt9QWCAURVj8RudBKh6zSRMY7QgEhxok6oNvGKOIuXTSTMJ8R9EwahbJ6YtQWSbPtXhKvztquwmTtpgej/iQGksW8jSsznOIvwkji5NtNKIplHrM3vEbUic1a6sTnhKkpu7gCYi0AV'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1tEOgCAIBVD+/6frIWeFXoKrNmvyJnKU2SpFRLZ4yOvsCJKFsGZOtxjN1BTJCvrQlTdf7Ypk0osBOpAZJzaYpRHFipiD5SmV0wwtW93l6aBhczH3TSYkS3mOWfUkix/Fr5mieViWWLKBBea9DPxqerGUZBh+MJOye1WMnS9/GyuozeBNyM9gG2hp/Lm0mfs+vlgvpmiEXegOPMeQ0g=='
				),
				_LetterImage(
					width: 44,
					height: 59,
					data: 'eJzt1dEOgCAIBdD7/z9tc6WTIXhxVnPFU10ODnsJABJZuNGyHm391rIqHVjRitga+itGLKat9r7tXGOxzY8Bi5W2hCJwD9HDU9YfSLo2sibj7dWiLbvqblb48iJ6BnfOeceeAW+7n2apbbqMTY9Y4U07/28xarDiZ6zwhK0DByAAib0='
				),
				_LetterImage(
					width: 48,
					height: 65,
					data: 'eJzt1tESQCAUBND9/5/OjIlc2quVqKEntrPcaTwAgCAsPOAhlGDW79t7m6vedvwJjvHpxKpHnc917vbZg2jj52vRowO/xLvE8ezB9Evlg3zUO1TzcVPyyuije9tZ7+w2rVzx9PWv+5hInpxxD34LSn2o87bjeOSOucyn2PcEeH6IP6S+ve2U+dSaAEnQsqI='
				),
				_LetterImage(
					width: 51,
					height: 59,
					data: 'eJzd1kEKwDAIBED//+kUCj1Ud1cFc0g8RieatpCu1Q1ri/3E3uhV14n94mKCtyBEdSVNeiQ92z9pLhSBJ5siPqcJzM0QmiVEZTcRvg/M6tZNgh9nWp4SUH8yAfJLNpolX4OY7yaiRCCwBhGjAqy6uxLPIOebJex+ITuh5AzJ3pZfjfXHkLAiCerJCR2z9INyMSmI8OtQiAe+5kgN'
				),
				_LetterImage(
					width: 55,
					height: 65,
					data: 'eJzt1kkOgCAMBdDe/9J1QUy0/N+BgENCl9TXgYWqOhIypB5j0mKAVJjcY7OQsTqzmT81UJllTVps+IzMPJd12VUMZ2eyq04y2/QPzDkmeXeIqK1nYobIZor0mS42pS+XJSy34zeYrwAjz0HWfzqKjA2EqzAWDbGSpasG9/wBZk2CAfI268/zzL1CXFVsOIyvmv1T3CxkOaVl0OIAPH+fww=='
				),
			],
		},
	),
	"Y": _Letter(
		adjustment: 2.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 24,
					height: 36,
					data: 'eJxjYICA/1DAgAZGxWkrTg+70O0bFaefOACujJ5w'
				),
				_LetterImage(
					width: 24,
					height: 42,
					data: 'eJzl090KABAMhuHv/m+aUuzvPVGUsqN5FjG0hiFWgWsE62m3unc/zzyupxSPe+nHHJBT/9gtdx72sHLRzJ1zxBrdafVb7+YXz1q/bAdgUi7u'
				),
				_LetterImage(
					width: 34,
					height: 41,
					data: 'eJzt0TEKwDAMQ1Hd/9IuGEJCrfp3SIdAvVk8Q0SkgFEOiw5JZL4TYrGsz2IkrcgUhc4R/nfL4T4hFlPVAvdOtqLr3z3vpQgWmXpRrqvIlYSZX+wXwWKqNbkATuj2Jg=='
				),
				_LetterImage(
					width: 29,
					height: 41,
					data: 'eJzt1MEKACEIBND5/5+eMBYKGyciWPawntTXJY0A1oEIi5UDht/DkWt8yhKj4xCfQ7GXdP4SYXGpcgk5bnW5acUHSIvRcUiBPTe4xI879H8H8zNkAwgFiZM='
				),
				_LetterImage(
					width: 34,
					height: 42,
					data: 'eJzt0zsOgEAIBFDuf2k2xpgVmBkojIWREl5gv+5NmK4e0ZS5sB0teFYEXEVuFwUaaDi+L8gl3jNK1H5jkRJZ1KWTVaOWk51jcD4tKXAjKPQfUcdLZv3idUHKl6jpBbLXFhU='
				),
				_LetterImage(
					width: 26,
					height: 40,
					data: 'eJxjYICC/zDAgA5GZYaYzCBxDorsf3QwKjMoZQCp3O4g'
				),
				_LetterImage(
					width: 26,
					height: 46,
					data: 'eJzt1DsOwCAMA1Df/9JGYqnzcUUluiC8kUdQskCawIEVoBXMuPpPIleChGaR9CxyzhAa0d4g/CTPQSWOsyJ5gbIXyAVJTM2bdCuXvit7pdSb/2QAgjmYhA=='
				),
				_LetterImage(
					width: 37,
					height: 45,
					data: 'eJzt1EEKwCAMRNG5/6UjCNVYzWQKFkoxOz8PFxEEYOlAREgh2kiIsPfRcIqRCxRdLUO1Kwj/Rv7MUEv7kGcErcsTdFtLgNj69jyFSaj2CNl8R7AICa3moE8i8VfvcEgFDJmLnw=='
				),
				_LetterImage(
					width: 32,
					height: 45,
					data: 'eJzt0VEKwCAMA9Dc/9IR2QrK2gTZxhjYv/TFDxUA1cC7rCDGeVH5xIdQ+pmV95Vx/N2ZffHlzDMO55Fv+HyjhTcpKsLpvK+MM/UjaE9m+7tO51EZcgP4vxQX'
				),
				_LetterImage(
					width: 37,
					height: 46,
					data: 'eJzt0EsKwEAIA9Dc/9KWFvqbJGoLXRQmy5mnohF10DA1wppapAhnGuQbdC9QiLqOSI6Gy0QWRYW4gpFo+wiNT4zELi8QIEhytOsaDbIhSYPTRv6wO0qvb4dO9FNkxYHExwKTzLF5'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 14,
					height: 44,
					data: 'eJy90ksKACAIANG5/6UNIsgJ+i2qjbyFGiqRH1hYWDwTFhYWK4UVVtwIK4Vee9b4/MM1VcrDsf4sY6fhMoazaWMs/+ljqw=='
				),
				_LetterImage(
					width: 14,
					height: 44,
					data: 'eJzNzjEKgEAQBMH+/6dbOER7A+EQAzeammRWH48BBhj4UFRUVFS8k5V7oqJKd793bW7IymoVlb+TldUZDjhoY6s='
				),
				_LetterImage(
					width: 39,
					height: 45,
					data: 'eJzt0sEKwDAIA9D8/0872GF0adSA9DBYjuVVbGiEE1gIPcMdxzQMMBjwQQaH8WjFxAYb04sSy96DNFNWlPg6bllZInc0ZXAYHykm7m1M70CsaUfkMNOY2NJ4ztaZPcu7Tob+bMZypX53wUoTzw8QuQAfmwE4'
				),
				_LetterImage(
					width: 34,
					height: 42,
					data: 'eJzN01EOwCAIA1Duf+ma7EctBUwk2/wT3qwaB8hhujz7lgp7RtXPSIeIyDKXYpsLwQUW/hOudIjPYk43Mi8sEChFRtiz8CtuRTMJsDZk/0wwY+EXikTx0uOz6qgL8XbMbzbSEBOHuF8BAwSmm48='
				),
				_LetterImage(
					width: 34,
					height: 41,
					data: 'eJy91OEKwCAIBOB7/5d2MFaI87xqMn8eX1pQmY0CTBQgDJ7SgpN10Tok6lR4Q4ALuMC5aGhxIEyCEZZC98gPG4fMjG5jpqnwBkQkxErxukJR3IEUFBh7ouXyTdHQ4oP4ZUjHNhZ+uniXZ12HQ3yu'
				),
				_LetterImage(
					width: 29,
					height: 43,
					data: 'eJxjYICB/3DAgAlGJUclcUriUsqAzxxqSKKp+I8JRiVHtiQAniRSyg=='
				),
				_LetterImage(
					width: 29,
					height: 50,
					data: 'eJzt0DsOwCAMA1Df/9LuUIY4H0tVhyJRb+FBIJBzYMwhMCDuGPoW4zbF1CNiuQA15yJnlBYJ+RhjqYip9FjHagaGvsxg2UHJK+z/qjn+43bYyMK0dAH+miAL'
				),
				_LetterImage(
					width: 41,
					height: 49,
					data: 'eJzt00EKgDAMRNG5/6UjWBBTOuYXdSF2lpNHC6GVFCiagHswLK1SPgeFYWoqeJQAtgmFWvAShn+7wzNeg8LQdtOwX5qHxYL773QLBoZt8gQc3mnXiaHJgv+BgeFZ53ID48BJ7w=='
				),
				_LetterImage(
					width: 35,
					height: 49,
					data: 'eJzt0sEKACEIBND5/582IhJbtDG2w8Y2N4fnoRCAkCBFQBg0CRKqA4idJqQ3hNSSE/ySiH9VzuJOggTR4i15vnLxt0I1JeMNB6SWW4gEpE2UuLnk+0QSRJVtCsUcrX0='
				),
				_LetterImage(
					width: 41,
					height: 50,
					data: 'eJzt0kEOwCAIRNG5/6Vp4qYVv0ibmrhglvgghGiWi5IuBdWSUwuoZ7LuEOjbGML8Ac4WUZCCu2H0RfriGuIi7+FYI4jNX6F8fj2/eTjzRtkDvWcIgxHSBgULdjBCN8SnC1QUccc='
				),
				_LetterImage(
					width: 15,
					height: 48,
					data: 'eJzN0jEKACAMBMH9/6fPQou4YMBCMNVNl4SD1MFERETkMRHpiUjPcuIKYi6JyJleYKadXDJi/WfE/E2Xz91cvx9eaKRq'
				),
				_LetterImage(
					width: 17,
					height: 53,
					data: 'eJzd0zEKACAMBMH9/6fPRsGwICIWYqowaY6EQGphQIAAwUwvAAIECDiAspHeCXIJEHhSA0wZV1CWuQ8RZA0R5AfwV/hxxkEbZV8LEg=='
				),
				_LetterImage(
					width: 15,
					height: 48,
					data: 'eJzV0CEOADAIBMH9/6evohWsIaSp6SnmDIRkHiwsrOdEpCMilTtXjJgxEelYyrPPp8wYMZX7kWL+YcSIZ1jH6qZo'
				),
				_LetterImage(
					width: 17,
					height: 53,
					data: 'eJzd0UEKACEMQ9Hc/9J/YDCDzUIRBWG6at6mLYXVUmZlVuarYDcoQAGq0OooEMAmdIt/J/VQ3OMZgNaAACbwoi1+9ieACgS4ewBXLAkU'
				),
				_LetterImage(
					width: 43,
					height: 50,
					data: 'eJzt01EKgDAMA9Dc/9ITRGG0SRucoKD92/a6pR8bwy3Y0qeAR7GX63qKqWz4ERqXkuZOSvkjmco8kRbRq7qHxkZJ8xuc0jirlA95lcKlaVNQ1k2oCpRoOySvN1LVkeh0ufPzzxOH0uiU8il/+jQtJf1+De3cQdXZBsqX7ko='
				),
				_LetterImage(
					width: 47,
					height: 54,
					data: 'eJzt1EEOgDAIRFHuf2lcuLCR+RSMqYnKsnm0TDV175S1dI+blbnt1bElbmO18Jd5aL+Ri+GIQxbFk+iRpzdleT3JQ3fGxWHEYTbgFGUpPy9nXCwj13tIzuMJXslykWOWZTxpi3w8pfCVO3w2FHGIDpxu6ucv5BMN78WcF6wfPzLUBmwHzng='
				),
				_LetterImage(
					width: 37,
					height: 46,
					data: 'eJzN1UsOgEAIA9De/9LVlREpMPghsrPzlMbESEaD8KSFsE8tCoRjRlCszkGAbCCRSxxSt7lsGImaSr2HhOqUIq+JR1xBgYK9TpBofQcBgaE50mIdOemReFyCyq8O4nWUS5+i6X3NUj9q/sG+bJv4ZWxMV0ru'
				),
				_LetterImage(
					width: 41,
					height: 50,
					data: 'eJzV1UsOwCAIRVH2v2maxhF6QfwktAwfR3RgVNUvCXo7UCQBpVWSzWkhDKWJXNhHDoQMIC+GtBAuhIXwcLUOQQRVkxAvj2nQSoC8xS4UcZmVEVuDwAHy3Dsw9Uy0TmZkf4BLEJ+Jz0Hv2kYjf/ornMHJxuN38tYDwTArHA=='
				),
				_LetterImage(
					width: 37,
					height: 45,
					data: 'eJy91FkKgDAMBNC5/6UjKAZrtonYzJ/htelCFdEAkDIsKhnuUChTPbSjmxkRoIWF5lnJEEbQbDfnnhij1QJRM9ULMCO9nbTRWQ/QwhAilxnzRv6jtpNQKCHXF4GC9FBi9v4NPqHZbv8tiTtv+6g0B9kJLQw='
				),
				_LetterImage(
					width: 41,
					height: 49,
					data: 'eJzN1MkOgCAMRdH+/0/XhYkCHbgMEt+yHErBRNUiIsoyABGVJxh25ATcNOPiiM62EDY2c1WtA+UwpLW/QbWV5OtDiDsmc9uDy3o44gS8V+JL17bdR6R1Fka/Ga/XfuilJhgmGYc545AevB1++DbHIW7IX/G13tIFJWUJPg=='
				),
				_LetterImage(
					width: 32,
					height: 47,
					data: 'eJxjYECA/wjAgA2Myo/KDzZ5PMoZCBhHR3kMVehSo/Kj8jSRBwDhCsVX'
				),
				_LetterImage(
					width: 35,
					height: 52,
					data: 'eJxjYEAC/5EAA3YwqmRUyagSspTg18NA2NgBUYKpEENyVMmokuGoBAAUf1nR'
				),
				_LetterImage(
					width: 32,
					height: 55,
					data: 'eJzt0DEOACAIA8D+/9M4GAdqbTQsJtoNjwghwgaeiw6sHT1eL/LcSz79deRiF6h8nzxKToPYeZFNTzV7qXbDcvwhyUXXti+mnHvuCpXvT7i04fzWAAATzlw='
				),
				_LetterImage(
					width: 35,
					height: 60,
					data: 'eJzt0TsOwDAIA1Df/9J0aYbYpBYVHSrhkTzxUSJcYEULAZ4I7ljwY0JeiLYsk3Qx5BnSS6KB8EglslWB7BUheuMXxGxGsV/BJJUlcpz3khAUor2GDGkkh+dFtHoB7RGFsw=='
				),
				_LetterImage(
					width: 45,
					height: 54,
					data: 'eJzt1sEKwCAMA9D8/0+7gzBsq7UZ7WHQ3IxPD4ogAIxoUIoRXYE1FL75X2A99LHs0vFbB/GcY7BJ4xqsqyte6zoMCjvtN2yP1MOBOzBPPwHrl5uI51wiHgKbbHdk8DGNG6dg7gMiVqj6AQv3MBc='
				),
				_LetterImage(
					width: 49,
					height: 59,
					data: 'eJzt1FEKwCAMA9Dc/9IOWWGstrMBO9xoPhufCKIA0JjgFXCGBkEEnQJ9AQ3UNAtcRRxIzYIxBb4BhlkE3Ip8MHthXrEDMG5oAmxk78KYMGj5QOr1wD2KC2RKgocUKPBj4H6BUaaLAxtvLyY='
				),
				_LetterImage(
					width: 38,
					height: 54,
					data: 'eJzt1EEKwCAMRNG5/6VTpNSaYJNBZlN0dn4eLlwIAFYOYlVLvONUIn+n3FGhnlSrVikVd1ShQkjUEJUKnOpJo+46Vfk7mt+imv5Ky6pVoYqLl1DqY0ftpIxTHbp0AaicZtI='
				),
				_LetterImage(
					width: 42,
					height: 59,
					data: 'eJzt1DEOwCAMQ1Hf/9JBWarQQGQVQgfi8fM2BAAg1JAkQXGY8TLWd8k+bJRP5aQe0NKt5Cn5LrG0OUOClyb+JDF6D9/uJNaElPF/vCr1IEG6OcLL6UqWPC+Fl0b3sQEHBlTy'
				),
				_LetterImage(
					width: 45,
					height: 55,
					data: 'eJzt08EOwCAIA9D+/0+zxMuy0aoMN3egR30oxGg2HwTsOxgt83KMcUnE/hK7YoXpTVmsZ0A/hfdjV7sC8644FiM8xGSVY3FEDt8X4H+TSuRBzWNdlMH9dpZhV6QwvUFg3k7hwt/iATyx2DwAJQlh5Q=='
				),
				_LetterImage(
					width: 49,
					height: 60,
					data: 'eJzt0dEKgDAIhWHf/6XtIog1/UvJEQy9tPM5t1RzJcn8UiBn5dIhIPfK5jcEzgQGcGQJeLzUDEw12BPYAXWAViSAd/oC3D4BHPQHMJ0xHvjz87Nl83r1loHX3YqBAxnASQhotQYNGsSyI8DvB7HnYvI='
				),
			],
		},
	),
};
