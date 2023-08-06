part of 'captcha_4chan.dart';

const captchaLetters = ["0", "2", "4", "8", "A", "D", "G", "H", "J", "K", "M", "N", "P", "R", "S", "T", "V", "W", "X", "Y"];

final Map<String, _Letter> _captchaLetterImages = {
	"0": _Letter(
		adjustment: -5.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7/x8CGJDAfzRAbTlkMXR5cuTw2UEtOXRxSuXQ3U5LOR4gwOUecuWoGdbkxjshOXT7/6MBUuUANiFPUA=='
				),
				_LetterImage(
					width: 28,
					height: 34,
					data: 'eJy1kskNACAIBOm/aTw+hj2ixsgPBmQBM/9bdLNAsVg2PIOoVrAoDHJQHzPOw1zLhC7cRe2n33N6L/cwg46p+Z+Z03I349m9YPaj+4hehcXuXshqLcja/FvWRLUQa5Sg2zM='
				),
				_LetterImage(
					width: 38,
					height: 33,
					data: 'eJy10kESwCAIA0D+/2k6gxfFJORQuQkrFqaZTyI8VeEpTlc+WoguWNVpLzEFGgiVngJZT4VS/dl/VFyr4vvpKjw1xabUBU9V3VPToMnVdqJbvQcbVWdEye86Ulol+1PwXU+B+jkXUyBam5X8AHiuZLg='
				),
				_LetterImage(
					width: 33,
					height: 33,
					data: 'eJyt0VEOwCAIA1Duf2kXM+MotuXD8Sc+DMIYv0VEC2a0QKCZDAhZfYKA6kFBLRRgPeZATbUgFNjpe1BGYMaW3muBCexNEQ9iLcsC85NvWQj2gQ+KLlgAJBTIHlJCA7pgVtOCegetM3BEvnvBA5WvFgc='
				),
				_LetterImage(
					width: 38,
					height: 34,
					data: 'eJzNkksKwDAIRHP/SxvaTROdTxACdZXPc3TEiH/EeMICihp7vE8OIoKU2tglWSgud0axLFzAU9xN7pv2pYs5u5YSaJ6aoMrxPmW7/yx0htbZJDTVQsGWjqhqJFKusEupKgjNyB1JgsQIVoRfE4s8hpY='
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJzFktEOACAERf3/T2s9pMy9KmvLS+HQtahWTIQmhqXJNwCgZggAPjQ9UtMPwTV0YKKISwZp3L4OcA12+wfIInQzShU4/osBxFXw9RoAvD7hnUySeV4R0KzRroA13gCCLNQ6'
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJy1ksEKACAIQ/f/P21ERjkH5qEdwj0lg2X2IiCBJQm7OHSWCfiYXdHMPGgmbvGiWA4IDFaB893e/IGhX97DdSCgQNzeGXAgSEZlqfNofZ/tBy8vPtA='
				),
				_LetterImage(
					width: 31,
					height: 37,
					data: 'eJzNkEEOgEAIA/n/pzEbo5Ey1GziQW7LsKUl808VqxxDHM9a75l2BcQhGJaIYcI4fDUGrR08nwc/1iTmADuYZ+62wT3ql3i25tO94CCcBleVdrWC+1qPZbZ84ASEVQJ9DglPTB5BQbsHWcxH1Q=='
				),
				_LetterImage(
					width: 42,
					height: 36,
					data: 'eJzN0UEOwCAIRFHuf2maiGmEAv6FJp2dnVeDqvqbCJcjXLZ+NhLTb1ZJW7u2kek+vVQu04JLOSaX9oa0isyZxAiXJKvc/MXlIFySC9Az0q2bNwpvyuWH1nI3p/+4lW9RXVAyFpepiaetZZpopnwAtlzqMg=='
				),
				_LetterImage(
					width: 36,
					height: 36,
					data: 'eJzF0eEOgCAIBGDe/6Vt6VpwcHirtvinfCrgGH+EmWJmKIa6c9sgmjsKs1YuQ0w6Tc11Z2/ypmLsnYGiPjA4PT407FMxbfBKUe3MTCumbc79+wNzr9icfceKQVWbrp74y9yE91LHcE4xKR17qU0RIb3MAVqSiZM='
				),
				_LetterImage(
					width: 42,
					height: 37,
					data: 'eJzV01EKgEAIBFDvf2kjgjCdmYZlCfIr3KebRpk/jzjDMfEio8WVNCDvLGTztYXuXDNcwtop2S07pFrGIyM3Zg0zY01qXo8NCZ6/lNZEN98ng0tUNSXqj78RkOQVbYmmy36g96Bk+wvEhHzDUPaCidj6RhyJlRAb'
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJzNkkkOACAIA/n/p/FkRGxxN3LSMoGCql4NEYlyOTrpowwCjQgZJ5prARsGFBuorS69wJAx4SKIlV0m9FOOXzDGOR3uJTPzpmr/LmEq0TFYRB07/tyyJ2egXSOmyiRoU0XX'
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJy1ku0OACAERb3/S2ttNC42ffnRuEdhYr42oqiIFfIJ8EwiD0ykbkibJ6ZBOfVCHyUIDRKlAOUOSGrAkD/AGqVq7AFobdnM7/PZAtgyvObvA6h2uf1FVRijmJF9'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJyNkdsOwCAIQ/v/P90li4ZedBlPchRakPwZaIJkeENrAGeAEaDJToywiZ5EY6pN9ZusJDsfnY0mm9izJmr30pw+GmJ3WybHb5LLWv3iTjd+I2Pt+Ilml3wAYmwe8A=='
				),
				_LetterImage(
					width: 43,
					height: 37,
					data: 'eJzdk0kOwDAIA/n/p6mqLkphXHOrVE5ZBrCzZP4iImLKTdC445xabkfXDI21jAm5qimoSFOuj8EIJY9t1aDYhrX2gtKWaW3RrpVPQ9Z+omjXifkIZVvZUPnWIA9QpWaOklBA+Z7Qo2otUPmA5AkY9NpmSW9/P0uoX1+5tXaWa3wPw22eQ1TW'
				),
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJyNkdsOwCAIQ/v/P90li4ZedBlPchRakPwZaIJkeENrAGeAEaDJToywiZ5EY6pN9ZusJDsfnY0mm9izJmr30pw+GmJ3WybHb5LLWv3iTjd+I2Pt+Ilml3wAYmwe8A=='
				),
			],
		},
	),
	"2": _Letter(
		adjustment: 3,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7////fwYs4D8UUFsOXR02taTK/ccCqC032M0bym6nZVhQEwAA6Oy+UA=='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJy9kkEOACEIA/v/T+MeiFpsjVy2J2UiFCSiLVjwycUlwxLlxSkLkrk7MeGnGqtM2J0n1bvqlZmrJUejxmnnfGWXhMrzK/vVR7eW+KfIPRO12juBJa5F8e09CuAch1cLdvbadWoArdKDmQ=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJy1klEOwDAIQrn/pbtk24fVKphYPvUF1HYtWQA0CpyEUR4Gr8omR221JPdKmZ0lkL1/dJKiJDv1KFU8w9fXqENfo2KYt+mP/Ja6I59tbF/ePMrbcCpXm5J/2xwqHeVivngkQz4aOmjC'
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzV0ksKACAIBFDvf2mjIFBxHKM2za58/STVTkQomKEgR2tSXNBigMwURHYIzwKbknfdg8pUrXsAysZTEGsUuJqGLh8sVvZp2L3t0Y2HxZgaBXn6oPU5vkWQbDQADnD6Ig=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzF0tEKQCEIA1D//6eLSxDZNudDcH3KOMmExnhQ4cVXFlQqcq2rAly2FlvZW1A0wNnrPY5ebps6qvjYWqlIu79nQCRVXrSU3oaiV6oM3VL/RGoQocQPh8dwxvGhfnSkIpEIyGODCnyqNrUAFAUkuqoJfPBpwQ=='
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJy1ksEOACAIQv3/n7ZDy0MKZha3xosxpuqNZAoa4gCJlQNG+a9bDMu0J63bB9Ai9SW3+BbwN/0EQDafh+1aAJJuDwDkw/Xh0UgkaDDRtLTH0gBYYHmj'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJytklEKACAIQ73/pY0KQt0kpfb50rVRqhXJFAAxWKIyvE784FmwmwHTqzsYC91bGoMGfnfIME3Ma3Twj8CFaPAU4kV+C4psJe5bA73lslw='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJy1klEOwCAMQrn/pbv9GC0DZhbHl/rSlhKr/hESu+UJDMaiPgBKiQ3sXwjzpHmRFnexXHAedWomI8Iu1Edd6XYdG/aCc2ezxznsTSd8wFUca6lpjB0sbX37iljEKxFaxoLLuJVwn1jDKi2Xx9AFbgEqAQ=='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzF01EOgCAMA9De/9IYNcYItS2YxX2yF9hG1lpVAMjlEblU/ExhDH2b5M+E492ZK0Q85idy8X9louVXVEo3/53kkppcRgUyCdovlVEXy/3yPepqE3JhJsOKvEsV5XJqB+a587X8S/HO3nwD+UdD9Q=='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJy90tsKwCAMA9D8/093jLHhLWkcxT7qIaRoROUAjrnHMQw+x+iHJ1DYnuVuGcy3lxtMTU+ahDnFC4x+voBjpmvH7FbBUOVrxxMWLRyjW/QZQUy2bHvrGDb1xv2VGv5y5YHeJkq97gIFLrN3'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzF00EOgDAIRFHuf+ma6EJLZz5oYspOfEFG7RhbKlrorBZiGbmuZoHUZEIP6W4U0mwzdyjcRwkvLF0byVlAwop3YxmlVvTVQm1JER3cJxm9kL+t2Niw+QWLx6pTzBKjLH+pUusEAWMuuWJIlE6cQXJAGQyNkgapNFAHbak/+Q=='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJy9kksKACAIRLv/pWsTSDafAmtWhS9n0Hp/qjalaoDJpTsmQPQ+N9O94+7iVzF8VOuJM0TKIEcpYD7ZnDEcsIMzq3nAuKiFDEfgn88OG9OwVE3LNSXGMPcAlbsLIA=='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJz7/59iwAACmCJQgEWIkAREDk0xQhOKdnQJHK4gVQKLFzHMx2Il7iBBNp9ECVyqqSdBYw/gkqCe+ZjiuCILa+JBlkAXwQ6wqMNjCwQAAEgkGAU='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJyNkFkSACAIQrn/pa2ZVoEWv/SNCRFhCkrADEis9ui1LyTWOmHbbpInhbMP4+zq1bg3/8GDzFkJH+VIluyIhE6sUYn1FUo+AnAxWebevtn5YAgro8edcQ=='
				),
				_LetterImage(
					width: 18,
					height: 39,
					data: 'eJzN0DEOACAIA8D+/9N1EmmLiaNsXCAWyadCCmADUMKuFCWGMeisewgnjzFkfZfpud6qoC7UfCVIsZ3eYl6QgSbUV6lJ28LluIkun/nN2AIrU9Q6'
				),
				_LetterImage(
					width: 18,
					height: 40,
					data: 'eJyVktsOwCAIQ/v/P82yxMt6tJn6AhQEClRdP9GWFkC0DRMQCUjTBzJ8JqfLinbF8jfJnq2Fb5artOejmJRySNHeIGeF4p9EJdMX6NuyWO/VuF8EhJMAgfWOfsZQD6IS5Sk='
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzFkTsCwCAMQnP/S9vP0GqABLuUEZ8J6Bg/KcLELpnYg8oLMWvI2cHlchmFI47SEZ0VfA1aNBFaqiNa8tlaFEPxmCQ9r/MhZbIQq0a0fVrQR9vtbso91Ny+X0iceindT4ZlPCWmp314SelgotUr32zye+w+q78giAhGUcFlVGMLWmMv2nOnDn8wg7U='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJyNkFkSACAIQrn/pa2ZVoEWv/SNCRFhCkrADEis9ui1LyTWOmHbbpInhbMP4+zq1bg3/8GDzFkJH+VIluyIhE6sUYn1FUo+AnAxWebevtn5YAgro8edcQ=='
				),
			],
		},
	),
	"4": _Letter(
		adjustment: 6,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7/x8VMEDBfyyA2nIMSIAacgxogFI5ZD415GhtPi45agJccYEuPhzlAJV+qmQ='
				),
				_LetterImage(
					width: 28,
					height: 31,
					data: 'eJzNkdsKACAIQ/3/n7YbYeoWRD20J7cTxkr1WEJBFcu/YGLaoDdMvDYoM9Jh+szMR7b6ZTZPeqAdI8P7W+TuBvvcIcCiEiN9Ygf/IojhP1SgS9bnAlCn5ig='
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJzd0ksKACAIBFDvf2kjWpQ5oxK0qFn1eYh9VP+L9NRUIMUqwmQLLpMrFLtfUyxLmXWVqXDVKa0p1OhVJVy5YzIVXqx7Ryi9QpQo1mpe8PTHbmrMKirv60U16Rg2fm058Q=='
				),
				_LetterImage(
					width: 33,
					height: 35,
					data: 'eJzV0ksKACAIBFDvf2mL6KtjQ9CiZlX2EolU/4zkUBAhmQESssSeUeCy3iYApp3Nc0MQluyOAjfRbTBIXKg10DR4KjWhwCEE0Ez7Lqffyr0DBfsZXgYdlVUC87PIVA=='
				),
				_LetterImage(
					width: 38,
					height: 31,
					data: 'eJzV0UEOwCAIRFHvf2kaG5sIfAcXrUnZIU8kaPZCtFr0KMEfVfOxhT5WUaAitFLhAqvYlp8TKs3hcz9GsQ/V/CnpEe6CGIkPxe6psqFwX/meUvwTk7Ic1P+QGvkFRZqmdg=='
				),
				_LetterImage(
					width: 33,
					height: 30,
					data: 'eJz7/58cwAABBKQHSgEDCqCFAgZ8ChgwATkKcHkTVYgSBdiUw4XIshCHn7B4GKYAhxRuQEgTpoU4fYEjVv7jAENQAQDYviT4'
				),
				_LetterImage(
					width: 23,
					height: 30,
					data: 'eJz7/58YwAACWAVpIcwAB+QLM2ATZmAgURjdgQgO8cIYviTaODQ3MaADLEKYALsiZOMwXEJWpNFNGACV42uj'
				),
				_LetterImage(
					width: 31,
					height: 34,
					data: 'eJzN0DEOACAIA8D+/9NoHAyFgpPGbnJKQLM7QWczteBDhkuvLxkxvSou994Vxa6SmSr+AG6sl9OtaFTJduAwp35KFyXnCC4/Ie8dfrNg46R2N3gdBjeBVMg='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzt0DESgDAIRFHuf2kyjoURlmULpXD8VYqXDMH9L2VHuuTcoiypparnNIkL5A1Jusxd5mvNTrh0XeLRh6QxCf5PZLd8B+kS8wck+ebYDMHoUpvzI3Lj53kBjz3hSQ=='
				),
				_LetterImage(
					width: 36,
					height: 38,
					data: 'eJzl0ksKwCAMBNC5/6VTLLQ2cfJB6kKclcaHKInIQUFLxfgOynAEneG0YkjMHf8YJ++p+qxjguKwrRjyvEXmo8ISbNPybpHZqBgC5w39RHrXzFBbI8+cxyZ9zz6mw3t1AciySuA='
				),
				_LetterImage(
					width: 42,
					height: 34,
					data: 'eJzd0UEOwCAIRFHvf2mbNN04/BnZNG1kiQ8FmfOTGC10RwudIYdGG/5QVmUkQy9LlZP1fvdyltCVZLSpNN2Sjv9ALZLkYVimwpCO2+SzpjQ/T2gjZbksFbG08a58EhdApD7s'
				),
				_LetterImage(
					width: 36,
					height: 33,
					data: 'eJz7/5+mgAEKCKsYBGoYUAEt1TDgV4MuTXs1aMqxmkElNVi1IATJtxqnN7EGAxZjSQDEaCRCDTYH4PE7zuj9jxMMAzUAYCiIlA=='
				),
				_LetterImage(
					width: 25,
					height: 33,
					data: 'eJzNkDEOACAIxPr/T2OY1NwxGDSxm1TlIKINSVF+KJg0BV7ATaFzLKcjYVZiH+N/lYAIruYo71Vi62bi6i5D+EQMSf29UQ=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJyt0ssOABAMRNH7/z9dmwrTkUZEVxwkfYj4HbhQDapRCERwWZE3TBABF13NvFz2DK8FrcvPNMVaedON3Vzad7l3aWbxKocx52cYDWNrow=='
				),
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJzN0EEKwDAIRNG5/6V/aUsyjoEQuqo7n6iJ8I+QVknSLTbx5iYpxekjpWFIizIxBdeGsAo7MSmLKXNffLW8sFMerAnnUu1cvu3ayzxLI7gApNChbQ=='
				),
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJy10UEKwCAMBdG5/6VTsNT+jLhoQTcxTwkxVn1eOIcFcH5EsPBHsGAZW0tt5TYsEd6t3jWDxFWiQ6I7H0qicu/zkT7nPoAhfWj5OfP2BQh0SMY='
				),
				_LetterImage(
					width: 43,
					height: 33,
					data: 'eJzd08EKwDAIA1D//6cdoxc1CebUwXK0j6kty/woESZ7Y7KdRs0/aMzY8DIlklHGOK0nFiUNTsWj/dujm5wY55K74fjyCnBReQO9onrPX4jsQzZdXkudOFSvRcdfaPZImhBKkQ3KAdBaegA3ji39'
				),
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJyt0ssOABAMRNH7/z9dmwrTkUZEVxwkfYj4HbhQDapRCERwWZE3TBABF13NvFz2DK8FrcvPNMVaedON3Vzad7l3aWbxKocx52cYDWNrow=='
				),
			],
		},
	),
	"8": _Letter(
		adjustment: -5.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7////fwYs4D8UUFsOXR02tcNVjhbhORrW9AtrAAhXLuA='
				),
				_LetterImage(
					width: 28,
					height: 35,
					data: 'eJztkMEOACAIQv3/n7YOrSZC5j1O5nMNcG/LJJhSe8rsKPxrWRIspt6BET9oDBnPkfNwv8+MdsSyVEx1gF3vGc2V+l03uo53xNfdb+4z5SH7AfeG2DY='
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJzN0VEKwCAMA9Dc/9IKK6JLU83Aj+Vrtk/rsDU7ADyFs8SSehg4u2NqulZrmSqSnSbs1GzdVNFw1NPy1Fh7ilmhiALvOjhCfYu3Wd0GqSR/7+Y7eioajvrva4uS2FuMoPCVNU2KaKy0mjQ+O+41e6E='
				),
				_LetterImage(
					width: 33,
					height: 35,
					data: 'eJztk1EKwDAIQ3P/SzvWgSwzNmX9bb5qeBaJGLEiwAK3LKChYYLUNTfQy9JQV6Y1/1QDae8DPPokOgs8pQUY6cJABaCXhR+yXXpZBTjLYqg4nwD1MUKKZxNQVHEEAkhovC6usy7u'
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJztkcEKACAMQvv/ny4iiOV0a9Axb5N30Nn7A7WcmEqBiGqnlhUAwMbEplLXUTSAvXUPcwdtzZX85A3lIyLFi1QoNB1Fwp4GL1XSXxufUN7xjkLTUTSrdXSb67pqR/EZDQwmsX2f'
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJztkUEKACAIBP3/p+0QCLqjQbegvUWzo6D7TWyn/TABjHMGgtJq0UzOeI7rPg0kFPouAElhGEg7oNX8Y2VAblH6LgBJYRhIp30WTI2yXA=='
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJz7/58YwAACGAIMSMIM6ACXMFgGVSFcA7JONGGsVg8CYbgkelCh+Q5NGIuJmMKjQYUBMC2BGQYA6DUo5g=='
				),
				_LetterImage(
					width: 31,
					height: 38,
					data: 'eJzFkUsKACEMQ3v/S+tsxJqPVGQwu/YJJk1r/yh27JMnYXAkrR+E0o4N7DeA8ac5SIsmZXYvUhaxuVENuwuPzTFeNoDBTRrIbE0vG7solEyd4FeNwVtplBLQcVUlnFKSDukPW8E='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzV0lEKgDAMA9Dc/9ITDIzZNiXChtgvTR7TwsY4NQB8eY8vO84KefrTWv4sOl5kgjofc7Y+J1ntlyx9ORNfJqpl5Aij71KRvx3/jPrnUIRi7X7rtf1WsnLlf+5SGc5Crxu5lh0vZPJ8lXLhfL4AB/EEJw=='
				),
				_LetterImage(
					width: 36,
					height: 38,
					data: 'eJzV1OEKgDAIBOB7/5c2YoSpd0vWCLqf7ttShMx2BuiYMx2j4CgjRr8g4b2mXLlHEG2iY/xkl0mzvDHjpGOujTybrLiJECF871hM56Zow4ghI1HjJ18a/HXvtTKfGCK5UwaLKZ+Z/bv8iQPUL7pi'
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzVksEKACAIQ/v/ny6oS9Y2S4Rot9ZD3LDWJypHUNcRpMmyapgOhCYraCLZh0OSbayjwhlH1mDeSSTLEid5PzMJ5sfIzQYkXH+1aNZr/XJL2VfHssTJD24JpWNQoAcvF5qsmAbe4wgj'
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJzlkDEKACAMA/3/p+siBMIZdXAQuxWv19iqq9VGpTdg/OmMEUjzLstu9av4/zF0KZMUMCinrRxgzgikeZdlt/r5fXYY/MLjDF3BJHQplNNWDpDDdRXfMes='
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJz7/59iwAACmCJQgEWIkAREDk0xQhOKdnQJHK4YIhIIaYzQRQ8JBnQJrAZjkaBq6A6pYKdt6MKMBABnCHyS'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJzNkdEOABEQA/v/P13iNtlW5bzqi2YIBvIQJMHOAGOzo6ILjH1NmY2ryg5J6h53giQwiT44CZKogJniJzmppvIur5qqcnxMK22MnTIlnZEDZ8Ay3A=='
				),
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJy9kkEOACEIA/v/T3cvwrbUGE9ykQwIbZS8CiQBRgMcoSIJjFDZSgV11mzUoKRkzDV0ff+AI6l7ZkAnwSIJjNAOdXqakYseOWU43SfdNsXBxW2+BJPY45vmD7LtaKY='
				),
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJzNkkkKwDAMA+f/n1ahpF7kNNBbdbE1xiQCS5+FexgA941hBIysPkjMWs1Re7QQOdGJ2NfvliPBCFUD4P6JiPPNZmb+T9JS5ZOynBHfDiCIUozLugBPwWim'
				),
				_LetterImage(
					width: 43,
					height: 38,
					data: 'eJzFlEEOgDAIBPn/pzHVaEiZBdKLe2SHIttG959kNsSWhtiHygaLcnm2sabcjiaLUTyiK5kYk0pFDrHURBZKdWw+Q1OnROWIA3QzRJ74XAhNRtaUy3OmfcNPEcs9BnIcEGElKm8ruh3K90eoHHGAit0TCmVC++79uag4bq9cER8EYIgKzt+/d4stXZMPSuA='
				),
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJzNkdEOABEQA/v/P13iNtlW5bzqi2YIBvIQJMHOAGOzo6ILjH1NmY2ryg5J6h53giQwiT44CZKogJniJzmppvIur5qqcnxMK22MnTIlnZEDZ8Ay3A=='
				),
			],
		},
	),
	"A": _Letter(
		adjustment: 4.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7/x8BGIDgPw5AbTkGJEANOWQxdHly5PDZMdTkaAEGk//oJQcAYTFynA=='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJzF0lEKwDAIA9Dc/9IZ+yldTEppkfnpU6pS8scAsKBjSz4ZLJheVMPHpEZnrFbrtDZa2DPNrG+Ffa5M88McvBby2h/BWeN+m2b/HeQUNNFnTsgHnE835Q=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzN0FEKACEIBFDvf2kXglBs1IGidv7Sl4KqryOcGtlWwilL1ucUSBzjW5kCAwqlnAJVTkml4tozSpZTZQrdqlOBVspo0mo/2y5OdZS7xCXlXrWaJUKB/FU5+QFtd/4e'
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzN0NsOwCAIA1D//6dZdtG5jraJy4x9Ew6GEDE5xYI9o+BoaFBDpg3APHodiBTgIAHXZwpgyYLCQCt/B3ACczogKegRBRWlZTn1upta0QK6w1+gPQQ4CwZgVgA32gAZVZyA'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzV00EKwCAMRNHc/9La4kbjdyKils5SnhMMmNJPYm+m0FYVUaeAGmQKlULrFF7wimv9OPFc0d2rYHX86FaNVoObOaUYVEqAoiKAtSFQ6st9rSj5s6ozoXj4ZSXIkwwb8P8d'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/5+6gAEE6KIApyIGOMArSZQCLKoQQlgUoAoheDj0QPyBVQ9O/+BwEUEnD6gCLNIQBVglyAI4zRpM4UBHBShK/+MABBUAAD+sHAE='
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/588wMDAQCVhDCkGKMAqiFMYRQbCQRFGcGAsNDUQt6CoQbUFyiDGchoJMzCgCTOQAbAYM0DeIUcYLVYx9KALAwCFS3iW'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzV00EOgCAMRNG5/6VrXIgl/dNEMUa7g0eG0oSIv5SkXhdZ/kxmGeKEnovOF5xbmDBWxHj42DBZE2OjY8GvzD0/NaP7XCQx285WIKYz5C+M5QK7f1HeH1hvMGPEBt5ZyFQ='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzV0MEKACEIRVH//6dtIUzWaF5iGujt7B0MVL01wqXlKylcuuSEyzB70uahXchwz1oql2HBpRTStSekVVRO4fJFcznzQjqft2hH/5dL4k/c83c5zKV8HpkMc4v0vAFfcaKI'
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzN0NEOABAIBVD//9PMGlFuZdjcNzplyvnvpIipOTJU8kwPnOEbnT1Dp6ECjOqGps20jb6MmISNePCCkZvZ2is2Uq3NDA2z+M1YcDr5kYgx3a39vDd8sg3d+EbnN8OuAMCCNvQ='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzl0EsOwCAIBFDuf2kbtYsqMyNJ4yeRpT4QJ6ULykqF4RQZ4E5Cb7B+SQytXgFJurxk8/3LMgeaIZfqi82JDIOuqGI7SVL0kdq8MoLw/IgZLXJMngtk14Ulmu8k3WSflCrXAxQypoQ='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzN0NEOACAEBVD//9NaT6RL1lrctzhjYa4Lzfw1ESTJoZ02CKoiNKaongKvDFiY2M+m7f6ztUGAtuu9SWZkZLresMSs2ho00TcDmLGKkg=='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzFz0sKACAIBFDvf2lrkZjjh4ikWaWvSJk7QjNPwSNJknYB1lZlYavk6K4VIKUCzBGsXA3YDEQI2DlO+jT65f/mt6DMmBQGCCfATg=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJytkdsKACAIQ/f/P20UmM4RXWhPdkody+yvgA2Bki56gYIw5ROF+IGIKclV2hLdsfeQQEm2RqTYJdte10tog85dJHVDIqkcjZLlv72SwRqS6XCe'
				),
				_LetterImage(
					width: 18,
					height: 39,
					data: 'eJzF0VEOwCAIA9De/9JdRqa0dH4u40ueIkTJrwMpmAemwOVO0VIFLhIu3LTSWokwhQeplTZ+LhijHAUpY9w2ybTxmnlvvFX4zP4wTJHbXPRjuk0I/5CyCxw7p2c='
				),
				_LetterImage(
					width: 18,
					height: 40,
					data: 'eJzF0UEKACEMQ9Hc/9IZENHmtzCrYbqSh20l2j+UGowiiIDa1eCYKOtAWdsgd+FuqoIFpaeKX0RowjNDBLkTFMN4b4igp+QGs5RIzqeFZGyfiCkJfgAverhW'
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzt08EOgCAMA1D+/6enB0MGa7sSTyb2JnmTMULEn5pxx4antC8YKc+CRXOFlGtFy7ZuNkmq4Nnn8S0KOqqrDSXbCKonx7p8S0mb+kJcl2jDJl0+OS07eH83qDkEPVcp0ePpaK3DFG5RKe1G55O0ccGfCsgFD7gMLQ=='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJytkdsKACAIQ/f/P20UmM4RXWhPdkody+yvgA2Bki56gYIw5ROF+IGIKclV2hLdsfeQQEm2RqTYJdte10tog85dJHVDIqkcjZLlv72SwRqS6XCe'
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
					height: 29,
					data: 'eJxjYMAE/6EAixTV5NDVUUuOVu7GJj8qR/2wxsUnV46abgYAmOsPAA=='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJztj1sKACAIBLv/pc2g8LkSUX/NV+6kJdF7GgNF5powqlSY3piv3i2Ki3j6dMDjH9t9v4tOR8j587Fzz1+fr+t6V5MHRxaUi0sE0wEmK9Q6'
				),
				_LetterImage(
					width: 38,
					height: 33,
					data: 'eJzt0sEOABAMA9D+/09zmIRUrbtw0ht7kg0Amg9GaiqX4NSUpFoxXXdrSq3vK2rupGj3vYqCVsmzfHVZaTDV9he1skmb8cfh+o2aG52vZ6Nz5NYBhb0MEQ=='
				),
				_LetterImage(
					width: 33,
					height: 33,
					data: 'eJzt0UsOABAMBNC5/6Ur0URa/cxCxMbs6EMBQNpAQ0GN4ENBRAnwyExREEZXQNLH47b865z/wAc7SIoLgII25dF0Wbn3nO+uJklsTcEAUTzQPg=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzt0jkOACAIBED+/2kNNoTLJYZEC7fEwXuMN0IcCHaKdFZpK/yEGZAJD1Lqw8uLQrZwYvK3+NUVZQeQcl39KtyrrcDTtCq9JfzD4TNY4FQIlMoFZwKl73uh'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/58cwMCAUwIGcEpgKsCUI04BQhWqCD4FWMz7j0c5Oc4iSQFWRYSCblQBFgVYpMmMLBQeFgX4eJQrwGEhhX7CKo2ecbAAAPlxsF4='
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/58YwMCAIQABGALIwgzoAIcwRAbBxiaMou8/FgUU2I/wIxZhDB1DXRiH5/EKI0cDtjhBjR3ihdGMI8lNuLz1HwUAADpuHPI='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzt0LEKACAIBFD//6ctB0FNrwaDhm6zF6IyvxSSIEuZbKSuzHfISDscBzXaMhxDufwCd4x3+tzL7hHwUlzmOCuqGplsyuv56yJzHMVyajMDDgpH1Q=='
				),
				_LetterImage(
					width: 42,
					height: 36,
					data: 'eJzt0jsOACAIA9De/9I6OChCsSwmJjLaFz+NANCkQUlC4jCjy4wHkngqHbeBLveV+5JdVnnAK3JEVIY1fPmopGhK8vMjKU0ma7ucDh2x0oorL+BrGR3AZ3uh'
				),
				_LetterImage(
					width: 36,
					height: 36,
					data: 'eJzt0MEOwCAIA9D+/09jsoPBrkgvLjvYm/JIAACIJjBN55DimAq+jHDSEMx/jlHvk2Ydqu7jzx8ZrLcNCkSu+dyocjJwTJPdFE7vxj2VZls+CMG5ZQzf3zzg'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0d0OABAIBtDe/6UzbIb+vgs2TJc5UWK+PCgHYiiQNEVNBki92UFNRmZFNSyhrjuJjAn+Gikr+fIRKY4QqZSeII05ZQ54ZJM0WsT3ZUlhNGmgUXqoRALGmAAr'
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzt00EKACAIBED//2mDICJZ1y3qljdzSLJyfxpmxmojSAkYVNXNhHGNG7hvyJXexTHfmXKuyuy/KQ0C+yYRmVlTaFB69Oa5EVrf+ctsoPHSejQjpxYH'
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzd0jEOACAIA8D+/9N10AFoGQib3eQ0RJFcB9DKiylFgKaFa2HhIR+m3eM6GlxARfc2fwIwg1oWSKMNwHbmM+i6jb+oXpQ5B6KXXLI='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJzN0MsKACAIRNH7/z9dQQ/TsUWtGoTiCJFCCaFFxRtEw6IyrN9U7HyQrMetTHJDyUR/CSp7UiHEP6Fdb4XT19YuW1Vkc/gI'
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJzNkkEOACEIxPr/T7smioEZPawniQdoDGgDTQNwgpPKMATKMDSKzGaaUGR3pDk53eYvieb+pXfJ0h0OVlnVJ0XSghI6pKiRp2yWZGxbPx9HUizi'
				),
				_LetterImage(
					width: 18,
					height: 40,
					data: 'eJzN0jEOwCAMQ1Hf/9KfoSA5TjsUMcASeFgKkYDzS3mWGshjWqvBNClEIaV4sgGRmv0IKT0uFZvQAltile+bP2IPfbavo+QXgBBCIKQCAyr2dJo='
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzt0EsOwCAIBFDuf2n6iVFLZ2A2tklTdsaHg7h/osxMdQq1Xu1YuoPOHZzdOkoWphHcSWGYFqHLthuJ9umzhmLJP11CPaHxhlEQ9xqFf+QMU5bzFCUuUvYe2B9nkBIXKWcXmrNBa7fXBlytdrQ='
				),
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJzN0MsKACAIRNH7/z9dQQ/TsUWtGoTiCJFCCaFFxRtEw6IyrN9U7HyQrMetTHJDyUR/CSp7UiHEP6Fdb4XT19YuW1Vkc/gI'
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
					height: 29,
					data: 'eJz7/x8CGNDAfyRAbTlsaimRo7Z59JBDDxtay6G7YTDJYQs3asjhChNy5QBPHHaY'
				),
				_LetterImage(
					width: 28,
					height: 34,
					data: 'eJzNkkkOACAIA/v/T6MHcQtl8WSPHWMLQaQsUNDFfJNhifkeSucoK/bWH0szvWWBZNFF4BLzJ7PAYASlGOuCoOf3DPFOz+fbTRgRfnb9nhozFwMa'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzV08EOgDAIA1D+/6dZgpcNSqnJPMjJkMcsM7p/UqapKE319OlbKnIKlvG0tyHDw0R5CtMotJe2/r9U+wlPBY/FKlOiNlk6Vkt4Qx1hkTX1cv0rl4TDkVlNmaamtPPPO9CiIMWK5erlAmyMBSY='
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzN0zEOgDAMA0D//9NGHZCaxK4ZGJqN6AKpVcjfCohgVQQGrSZK2emJUKY5hRiyT/unHa+bJcBLgTrLTCWCig7ByyXR6vzSbuVqoL6NbfATqEQC9AuztyLoKTuACN6WzEfml/8xzorA7qDRA7Beo3k='
				),
				_LetterImage(
					width: 38,
					height: 34,
					data: 'eJzV00EKwCAMRNHc/9KRFqpG0vwR3JiFC32YUdH9QBmLpxBUymIh0BD2wsjVoboSiNJLVEqif/QuVc34npOniCoHkyrAUIT2FaU3OsL2TdyoFpqracN17hvChnkKOacf+LUN8pG4ZA=='
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJz7/58cwAABOCUYsCpgwAQUKMDtMAKupoICXPL/6WM9VgU4gw1LqEIVYJWhiQJqR/4gU8CATwGqMWhC6Aow9OAyEIehOByOSwIArlUBHA=='
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJz7/58YwAACGAIMaMIMDOQIY1qF1XYShbF6gRoGM2AVRAgzoAJMEQqEyQ1iOggzYBNGaED3Hopa3L7GNBHDfhgfADa2Ya0='
				),
				_LetterImage(
					width: 31,
					height: 37,
					data: 'eJzd0zsSwCAIBNC9/6XRRmYTWSDJpJH2Kb9Rs38Cmc3QAsGg0FLpo5LO6ShSG4k/sexKbxgmR+rvkHkT4tgWS21z0hrqzo/jy5mNPcX9Dr+1sFqchvjlJxo8uoOZ'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzV0sEOgCAMA9D9/0/PBDjAaGtJOOhOhj2XUc38TIUvW/lS+tGJWnoY4/1xaRAqR3CZdbcbEgdjS5TPr6T4N6ok86nc+C05c3C20d5Cb3MPJdzZl16G64kv1bVOJbsWDeZQhi+nBpXyE9YEOQeSeCpf9lT8AbFur3s='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzN01EOgCAMA9Dd/9IYNVHoutJIou4Lx2PZCLb2RUQ45gjHlG5PB4SoQdy56rIE0ZPic+ziuSHzGgan/qdhNBlSkhqAa0acC4xi9uSq+xl3HIMvR03zzs3dGWVyT6K2Y64kM7O/XsNkiKNG9FO5DQgJO+8='
				),
				_LetterImage(
					width: 42,
					height: 37,
					data: 'eJzl07sOwCAIQFH+/6dp0g5FFLghMQ4yOOgJD42qR0IQegOhXIoPhDBEdckUuTGSKVp2jyx71Bp+h0Vh9G7L1/UyREbmxkgCmxJMJGSs3i1dJz0PpU087f7rkDjsCTeu4r7JEs2pg8MH5B1T1w=='
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJzl0SEWACAIREHuf2ksWpC/GCBJdEceqPto2S6VgYlxi5Fj1mu0GSZexA+mfVow4tnTjzkGwkkDWm/0gTFtYrd4dpnkHvel3rwJRwu6D4qS'
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJz7/59iwAACmCJQgEOYRAksduJwCBkSOPyERRiHBC5XkiyBJRAY0AAWIYolKIqawSDBgF0CSROChyKBrAxDL6Z+LG7BEAIAdPu9UQ=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJy90MEKACAIA9D9/08vkMA5jTrlrRfJGvk46AI3xOgboBpk4lgEZLlM4V4hoslM+EPSLbBLucuvymZrRVd04ST3KOzCR/HSj3G9rC5ToWELwAVxnQ=='
				),
				_LetterImage(
					width: 18,
					height: 39,
					data: 'eJyd0UEKACEMQ9Hc/9IZUGz9BHSwG+1bGK32cyklSKJpiLqdfZv2grhstS5aS0cyJqSj47rvohSl4KU4r3bCzqQ+VMeYa7Az2D9FFG8ZzOWw+LGgmOdt6MM+AZ+oZg=='
				),
				_LetterImage(
					width: 18,
					height: 37,
					data: 'eJy9kUEKwEAIA/P/T6dQ1DVRWHqpJzOIhkh+LrgGBoBrIQ6uA3Q9jyw+7s4UvK0CJBYXRcJnbUGvATBAEhqRQUbkuvk/UsczgNOdwT2DWFawJ79+sIkHeJmDiw=='
				),
				_LetterImage(
					width: 43,
					height: 37,
					data: 'eJzd00sKwDAIBNC5/6UtpYukjqNTKBTqMnmK5hPxUQAmO8NkM8UeJmvguyzJfpIw2aIG9OnYJZITcttpC96LSMnnV9J0v1APKDtKsxiN+Ih2aTziSI3h+mP9KeWng8qJvNqV3cg/IRvn1q8VZ8RVO/InamNwB7fXkpg='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJy90MEKACAIA9D9/08vkMA5jTrlrRfJGvk46AI3xOgboBpk4lgEZLlM4V4hoslM+EPSLbBLucuvymZrRVd04ST3KOzCR/HSj3G9rC5ToWELwAVxnQ=='
				),
			],
		},
	),
	"H": _Letter(
		adjustment: 2.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ2MylFXjt5gMPl9KMsBAD4hKuQ='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJz7/x8nYMAlDgI4JWgqh6oGIYepnwENjBQ5dHG4HDYJkBwOcWIBTqNxuWcQhhkV5LCmYQa0oP+PBdBODpvM//8Alt7wHg=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzl1DsKADAIA9Dc/9J2EWrFT6YimNE+lCIIQPpAw6kajlKm1ih9YNSTDcqzRDlaqUtbVTXgFDWH+97UDX1Skp+KoAGngkxVRh7WcpmD'
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzd0MEKACAIA9D9/0/XQUqL3E6RtFvjJSiARgOLBDl5B7whwFoBQv4AKzmCiFIwEAXpPwnEaLlBhVPfA/NBgBUC7KkAHHU/c0TY'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJz7/58wYGAgqAAMCKsYWFVYNKCqwmUsA1YwqopsVdgVIKnCowCiipAC8gBBuwl6YfCH/UCrwpuBkcTwqMJuOZ1V4VECBAChwJqC'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/x8PYAACPFIQQJwCTJUMmGBUAS0UYJGGKMAqQRuA07LBFFDDSwGK0v84AEEFAMpwxEo='
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/x8LYGDAIgQCuIVRZRmQwcgSZmBAE2agHsBi+uDyPO2F4ZL/0QAOYQCnsUDO'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzt0DEKADAIQ1Hvf+kUN2tjcBKH/vWJiIDKpCo2T9kQ57nAbI3lPmt+JDA351I63E3dUJ+/4albGDXfW0CbYI7AAToVcqo='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0cEKABAQRdH3/z/NRhqD5ioLU+7OOCVIUkHpSApx2dJKOwWybVHp+pLIie6l54E0Hslb8dP4NfgDZfn3h+WwDmUfMrksi7S8AtKBFhU='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzl0TsKACAMA9Dc/9I6FKw/moBLwGyGh7QUABoJRMMcwJWHya420XMz52ezq7tZYWGGI+Ypyu/KqMrabvfyMPmqTTTcnHEz6ToO5ctR'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0UEOABAMRNG5/6UrwkKqI8NGI/76lQYzLUCEmkRLQplkOOYlvwCsLzNIiga5Nl0qaFOepawsPUCaP3peuqlYRudPkm5yTy5VrQCTTxsQ'
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJz7/x8/YAACAkoIqGGAA+LVYFPNgAWMqhmkarApgKnBIUdTgM/awRqGo2qgorjVYDMRtxoAZh0/3Q=='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJz7/x8rYGDALo5dggEM8EqgKWBAAaMSuCUYGNAl0EUoB9hsGXifD2YJhPR/dIBTAgCpyo2B'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJzF0UEKACAIRNF//0ubSJv8W7HZNDyJCCFayFiYlmpNsktYFyzXaLE8U4su+KVvf69Dq7LEtJQdbh1FyQ=='
				),
				_LetterImage(
					width: 18,
					height: 39,
					data: 'eJzF0UkOABAQAMH+/6dJkFgaF8RcmDowC2EMwIKFH5Jug2ApcUuwYMmGqEm6g1r69g1/tCzwpNNgKfPu12CZr+qxJIt2t3yS'
				),
				_LetterImage(
					width: 18,
					height: 40,
					data: 'eJy10UEKACAIRNF//0tPu7Jv0MrZhA9Ew+QXaIDracGCpLayMy5IQIIEJddTWxvEdR8//Hed6Kz5PtqIxHJDFr/AjYE='
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzl1EkOACEIRFHuf2m73RgHoH5caaytj4CYWAqNQVZDnabWhcs7qVvm0KjDRLNhLMobNHQTzVxHBWsUuEqXSlbGWtDLwX0d9rD7VPw0wwmgbouVhtPkuZIK16h2fz7n/JmR'
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJzF0UEKACAIRNF//0ubSJv8W7HZNDyJCCFayFiYlmpNsktYFyzXaLE8U4su+KVvf69Dq7LEtJQdbh1FyQ=='
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
					height: 29,
					data: 'eJz7/x8BGNDAfxrLIcuji4/KDU45dHWDVQ6Zj81v5MgBAE1P2jQ='
				),
				_LetterImage(
					width: 28,
					height: 35,
					data: 'eJz7/x8nYMAlDgI4JbDIMSABnBJ4pIg2j5AcHjfic/+o3FCVQ7BR5VDVIUuhm4FFHWE5LOrAfAYEQJfD5i8QD6sEsl4s4gDBaoOZ'
				),
				_LetterImage(
					width: 38,
					height: 33,
					data: 'eJzl0kEKACAIBED//2mDCkJcc7voob0Zkxqk2h3h1AynMio2JHuhlWpVjMq3/0dhDhToHCkL+xV+wOUqp4RT5xgq9T8dq0h6BYZtNQBYkC/7'
				),
				_LetterImage(
					width: 33,
					height: 33,
					data: 'eJzd0rEKACAIBFD//6eNHEL08lxy6CaRp0ikOhyhYIeCCokPFz30FlhNQH3kRwDABOI2CDwZB6dRvkMLxI14Ri4gf/cEIIrAI6utswD9E8RY'
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJzt0MEKACAMAlD//6cXRBBbmgTRKY/j6WERPoAFPV5ohRIL6JIX11WxXNXFr756p/KBKFKrCHRcts6Ubo0rcrjiYH5gB5ZBDRoGH3mx'
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJz7/x8PYAACnBIwgFuGKgrwW47DfciqRhWMKsCuAJOHUIBDOR0U4FDOgM88VIDL51ikAW35hpY='
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJz7/x8LYGDAEIAATBGShbEZi2Hf/1HhARRGZUE4GAqoIoymgAGbPgRAdy2KIACSQKtj'
				),
				_LetterImage(
					width: 31,
					height: 38,
					data: 'eJztzzsOACAIA9De/9IYXSwfG3WmG3kNATMVSFWMGWUlg6NM69viC+aK/qm5+Y9piBy6TvMqN71xLG8GJ3H97poPVl7jMgDBOxAb'
				),
				_LetterImage(
					width: 42,
					height: 36,
					data: 'eJztz0EKACAIRNG5/6VtYYuK0SaohdDfBS9Fs6pBl54uBY61A7qZrtvH0p/3ZdKXgwz/UElXxHLVZWV4fz5Al9AlP8DmEGckXdK9XTY5dNxO'
				),
				_LetterImage(
					width: 36,
					height: 36,
					data: 'eJzd08EKACAIA1D//6eNPBTi1B0iot0cj0Ah1bcjjJlhTAPFhUK0u2RsOGPavb42EAMTXGKcetzsqjbhSsXjjFktNODrAZO4YDy0waoBGaNN3Q=='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzt0DEOACAIA8D+/9M4aIwBinVwoytXjJhpAUSoScxIqJbwUQzbqKlvMhTor1u2bBknV5mWAwTS8hqQR95lVd0DuFDJ0HGc2mSbKzMAEsI6/g=='
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJz7/x8/YAACAkrwqWFABnglqaiGoEPweWlUzaiaQasGCxdJDU4tdFVDhBasatAB7gDBpgAAipESGQ=='
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJz7/x8rYGDALo5NggEKsAiRJ4HVdHRxZMlRiWEigcaE8Bgw1VBRAkUJA1J6Q5VAAhiORxUGAJVYFwY='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJy90TsOACAIRMF3/0uvlfLZ2Bgi5RA2EKTZAlyaQTe424vIxZL/SmjItiwMSHyB3HTB5SSW3epdLjEqLU1FaqQ='
				),
				_LetterImage(
					width: 43,
					height: 38,
					data: 'eJzt1DEOACAIA0D+/2kMm0gLxMHB0FFPBAdVu5Ems3RdTWVLk2XyiiUywPc0HKBTxdpDh35J0R6grEa+4q4qKOqetBkoH8fR/H0EBDBIidPj2+HMsgAhH07q'
				),
				_LetterImage(
					width: 18,
					height: 33,
					data: 'eJy90TsOACAIRMF3/0uvlfLZ2Bgi5RA2EKTZAlyaQTe424vIxZL/SmjItiwMSHyB3HTB5SSW3epdLjEqLU1FaqQ='
				),
			],
		},
	),
	"K": _Letter(
		adjustment: -3.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ3QUg6ZTw05aptPjzCgtRwtwoWWdtAqPNDlSZUDAFHlZqg='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJy9ksEKACAIQ/3/n14EHWxtIUV5s2ebioCNcO89LDhn1ixnms0C2Yt9c6qY69cyrb/zDtYrM7GooPjN1HzEpl0E1bmdcSmG0IF/da6lL/dXsNvbf8AUARoEsCvx'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzN1EEOgCAQQ9He/9K4gQxqpT+RRGdHecAQEiS1XOrF1Br+Sk1ZUH2CqFNFUEpMmTAlo42wN1P0ut+rxlSNd6orvaVMVbpTTVnqdqXMsUyNyCq33Kv4eTH18K5v1AErf+4u'
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzF1FEKwCAMA9Dc/9LbR3Gz2iQyYfav8RVZBwK4ZCHKAk7OgTcRIFIDupKHD4AFYyT7aiadWbDwPX+Dfv8EtG4fkD3kloIW7YP5Ujqj9pcnBIigANNYAeTjYEH1Z76AG1E2l4U='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzN1FEKwDAIA1Dvf2k7xqAsZgktbsxPebVBSjN9RVhwlhe9ymcqLa3IYEzEI2JPKDp7SekEV9fkvCm6lCVFL0PFI/1KITWqvolgp9RWxcmcV7Sk3VtSpaj4wEf10mfwuRLkqAGS+e8t'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJzNkDEOACAIA/3/p9HIRNoSIA52lANzNUuyTpKRpwYguTAMCCjZNwHg9xPg9T0AaCPRvl3ZhwDt4Y7IlfhUByY7DBBy7jGxbwHKqQsITXFGARsYFhcG'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJy9ksEKACAIQ/3/n7a6lFtGatBuPhU2VNWRiIOGzhi7YoV4NmFWCa8iiqt7BpP7RKhPmHz3spAyNoOYrJkrvuVjT3e8vQ8tMG5vfmWp'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzN0sEOgDAIA9D+/09jPJhYWqpmh8lNHynDWZUKURPjrGSrnAbT48gtB/e5kEPQi4Ft1Cr3ZmbJUpb9X7G9BUj9mKlnZr5vSHP45ldC43Hcw2FpH+35yrpGSLBs/lSfsI89Vh2iybJq'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzV1EEKwCAMRNG5/6XtppShndCvRGiznDzRiChJA5WmpBCX12+lp0CeLSpvhdCKFJcxJpkmNmkbce1uvyYHl5bskA8epuDSGjukp60yvc/iDsPyV3mFhYytUqKfm8t82hZ5AI85f6s='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzN1MESwBAQA9D8/0/rwYya3diE9sCJeEoxAKCJAtMoB2h1h3mz2vRcm7mI7k0Dx6QwKzZw+VmMmYUpfsHYqTvMVC/MaP9lAkyZY8iE30y9xj0T70/YlLAox/SEGjKWGfXOOYYe8bF5AOQAHg0='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzd01EKgDAMA9De/9KVIYIsSRuUCa6f821Nx8z0KsKEnoyzLLRIehHJYitpC0h4zywkmQ6laLJStsGvD/2Ik8y5nkrRGKWKuIcEbkj2PoPvZTevpd3s5QCf3DbzIOXJhSz+zfrkP8hSjToAUSKNnQ=='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzV0FEOgCAMA9De/9JIQtDYtBsgfLjP+phZS4kHdRKSGNwzbpSGGG2Cv75CaSj8ZuIL+c1hY9qk4qQB8d8Z6H7aV7WMsznzhCtGhZkRa7sxrVBx24w9c8nY2+0yby4K0YKa'
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzFkkEKACAIBP3/py26mLtblAR5s9nAQd1lmel3DWzUFkDAUgEInPNOILobkEegzAOAmiEg/X8D9Oh91VzEluBogyQw3weaFQANeATEieInAg0o46Js'
				),
			],
			_LetterImageType.secondary: [
			],
		},
	),
	"M": _Letter(
		adjustment: -1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ3QQg4mj02cEjlqA5hduPxHrhw9w3pUjjpyAKipEvw='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJzt0sEKACAIA1D//6cXgRHGlgl1azd9VhQBMqb6PRKeWpyZFtcbydbcmVlmCg5SPtN7zJCZuD97z29lo394lMzWve8bE6ABmG3YNg=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzt1DEOACAIA8D+/9O4ODSItIOJDnY0Z0MYABA6mPFUD6+qzOgJKVWBp9ZIQEwq2eKpgxORaj7QEqRSW/3qSRX7U1EUeKrIq4rkAB9keaM='
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzt0DEOACAIA8D+/9M6kEDA0MZB42A34GAAwKCBRYKe3ASZRI2UZU+CGjp0QQHdlUBc3wCNzB9sAXnUB6eBFwRYQ4CaF0CgCTryKPQ='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzt0zEOACAIA8D+/9NoXNAEW1jUwY54QoLRTAeQYESLuyq4sKqgLfZJKqdEoaAUKCc1lio/IsoKSq2WvONXbyv6gacaUfHww4qQngYZkXqi'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/x8PYAACPFIQQJwCTJUMmIAkBVikIQoYcEuju4hsBVQDOK35D3cIVl0wcYoUUC0uRhUMPgUoSv/jAAQVAACBsqhm'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/x8LYGDAIgQCuIVRZRmQAQFhBgY0YQZMQWRbiBQmA2C6BWI8hrtJEyYjTEaFcQnDJf+jARzCAKscLOI='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzt0UEKACAIRFHvf+mJFkLJOEkLadFf9kSiAJVJVWwzZU0c5xYOa4x2Yp+5YquwsFri+oL9lDMqnD4d/5LPrzFy3reA1sEcgQFLHFrC'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0UEKACAIBdG5/6VrF4ZSU7ugv1NeigTQVDiSKE7MKzLR2CSlnuNlFYUOJV6qaV7qtXdy/SpebaT5oy+/THKqt3I0nSzzioy8A/Ij+yE='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzt0TEOACEIRNF//0u7hQUJRGasNGanA5+SIMAQwTTKgVZnTFbRIaXedkyNOLYNjhEPOEaP2TRLnb+gMe2ef/OKiao3s6NNzW0m3AfRl7Bs'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0sEKACAIA1D//6eN6CJma0ZQB3ftWQNT5SJCQk7KCIV+kuGYl+EDApOQht+StgIjCXMYtsJWmlMsNSmZRcEfUrIkkm4qltH9k1w2eSeh6mlQfgAr'
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzt0UEKACAIRNG5/6WtjUExjUVCEP31Q0TNdKgFJDBorRumQdo2DLiBEr08NxdSS5kLdcMsk/zTbx42vR4Nmzg3Bd87EA0='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzt0EEKACAIBdG5/6UN2pTyKwmXztIXJJrJQM81MLtCeIDrDRABNXbf5aE8sbBeYLtMHn6P2FAGiy12hAHYu2yi'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJxjYPiPBhiAAFOEgVoiDHAOXAQqBmYgRBgQ0jARNIApgq4AUwRDD8QpmCLICrGKIHlpWIiAKYzIwxQhFMEki4DFAK9xNdk='
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzt1EsOABAMBNDe/9IVG+mHzlghMdu+qhBU2QjJeliHqZjw8moqIbZQuVHOE6Y0tMmSurY0BzVwLPSwa29sA1PlaDpjOLS8CEvBnX16joKfxlUIOh2R6XI3dZ6kwKl/dCANdFF1tQ=='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJxjYPiPBhiAAFOEgVoiDHAOXAQqBmYgRBgQ0jARNIApgq4AUwRDD8QpmCLICrGKIHlpWIiAKYzIwxQhFMEki4DFAK9xNdk='
				),
			],
		},
	),
	"N": _Letter(
		adjustment: 0,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ3QQg5ZnppyMHlqyf0DAlzqyZWjd5jQO26HqxwA3bsO9A=='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJzd0tEOABAIBdD+/6evMYaU1Hhx33KkMYAa0tZzVHhq855uaz+xbG1wbmRZdcnIMHeCc4pF7nZg7rf+08Q/3ErJ+Nn3TRIgASZe1Do='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzd0EEKACAIBMD9/6frUihmugfBaG/qICKAkQcrnIphq7JMtWDiLeDUGU6BU0IvI07JqFJlJ6es8qGtKvvXj0pVsdotQjl5VSk5AR5GdKg='
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzV0MEKACAIA9D9/0/XQSw02w5B1G6OJ4gAGg0sEuzJTRDJnBGy7EmQIwEkcFTWEnh/DshpVJTffxewP/wKxkCAFQLkvAAm6lZxJPg='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzt09EOABAIBdD+/6djPKDlptV4cR/bEathtkNkghZbvFXKgVXt2pKaQyWormRDpIYFihwqnsTHdJU0Kq+Kb/srS8EPPNWA0i+/rACpKZ3Rdac='
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/x8PYAACPFIQQJwCTJUMmIA6ChjwKUA1hmwFCMsoVIBbipDBVFCATxV1FdAwukcVYFeAovQ/DkBQAQDe76Rq'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/x8LYGDAIgQCuIVRZRmQAanCDNiEERqIFIbKkCKMKYRFGQN23XiEscmQJ0xhwA4HYbjkfzSAQxgAl6Ao5g=='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzt0UsKACAIBNC5/6UnIqIPpmXhqtm+QRFJLVBVY+RoFsRzr2NpDOZYPHROGTtcKzLDZl+uVhZ2n/yGfQ/93JhrHqdQTATLSCZiEFXH'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0UEOABEQRNF//0uzk5p0oyxkSPwd/SIBQLFiSWJxtFtkoLpJKD/Hl1k7JL4U35/6UqY75Dj/wv9+zznSePkno/ysp7JtejLtFqm8AnEu9iY='
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzl0UEKACAIRNF//0vXIlDIalwERc0ufYIYQBEhaZQDrc6YXnmFLnE6Y2J2GTLG3LiRMdbZZdaLCjT5xJeMuOFPxl9r0yraxNxm3FViWKtx'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0jsKACAMA9De/9KKuEg/GiFVBzO/1CItBYsICDEpPRB6Sbo1LeMHJMqG1JwgzQoLORTmchwNSVoSduuS/JXJknZ1X56SquVLb76R4Sb35FS1VC0P+yE='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzt0jEOACAIA8D+/9PoZJRgIRGY7MqlXRDhwYxDHIOVuLE0jKQacKPb3sw222XoNTCQZjgsMR3/802BObU2VuPdDDLUEA0='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzl0UEKACAIRNG5/6UN2mTylSh3zdJnKmSGkbjOoJkSQoO23IAY3KNz8Ee2ANSwU9mIEnjxA3T8x1+w2GJSGOq0bKI='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJy90cEKACAIA9D9/09biAluSESRp3yHJQoYFWap4JUgm5Qwf4jgREpopFWhj1ej0oZejNeIqdA8PyT2QMdT2R34WNwGKD8y3A=='
				),
				_LetterImage(
					width: 18,
					height: 39,
					data: 'eJy10UsKwCAMANG5/6UjlBRMRmgRzS5PMD+iB2DBwinBgoVMLFimqPLOMr9b4p/kd6s662aOSrG+rA0JS45dj2f5OvAVeWwA3BFppQ=='
				),
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzt1DkOwCAMRFHf/9KEpEA2ePlINEiZlmfMJlqjEcjeUFdTUeHyTuqWOTTqMNGpTEJqypa5Q6r7IDoWg9z5wL5bW/koOqaNEzU0va38DfyU0+KnMSOAui1WGq4mz5W0cIPWrucBpBBvuw=='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJy90cEKACAIA9D9/09biAluSESRp3yHJQoYFWap4JUgm5Qwf4jgREpopFWhj1ej0oZejNeIqdA8PyT2QMdT2R34WNwGKD8y3A=='
				),
			],
		},
	),
	"P": _Letter(
		adjustment: 1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYMAO/gMBDimqyP1HAtjUDWc5bGppKfcfCxiVI10OADGFepQ='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJztkDEOACAMAvv/T6NxMdojaoybjL2GANKxwoIqd0cWXYNvZFnQWP41j+zCkVLmhww3mrvsMNoAtu4Mos15yX/ZU6Pc3fX77JYRkQqqzz/d'
				),
				_LetterImage(
					width: 38,
					height: 30,
					data: 'eJzN0cEKwDAIA9D8/0+vsBUqmsUcPDRHfVS0AJ4+2PGUlsjxFKVcZRqr/7JUKOsmKHVak+prOIptPXNwTyWq1KGtUg94is0pJbre0D++bUvV012lAhRkAdNOKvI='
				),
				_LetterImage(
					width: 33,
					height: 30,
					data: 'eJzF0VEKACAIA9Dd/9IFRZa0aVCQf+mrRAGUMNAjBRrBRwp2RIBHS4ojdbRU/CgHlr4HvvX78RzM72DAE0kwUAjkvRSwZZH2Xi2rlTLAPvwDzKhqBQOq5yc='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzt0EEKACAIBMD+/2kr6pC6rgRBBO1RRlFFDqTkoicFTBWdUSLAWC6minqTNj6e34HRTaUaoHJjt5UtOgWXXQvxRfjceIMAYGWBUxBk//rqQUVISwVcGw4d'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJz7/58cwAABOCUYMBQwYAf45CAKcMvgNROXwXidO6QVoCjFov8/hgJshmKxjBoKcPrnPxaAV3JUAV0VAAAjZivx'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJz7/58YwAACGAIMSMIM6ACbGEgYi0JMnZhGYrV6EAjDJdGDCpvvcIUJscIY7sESS+iCI1wYAL+ZeJY='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzt0DkOwCAMRFHf/9JDCiLAzEdQIKXIdPix2Eh3Eit7whLA0WV8IFxWVm8wB3g3MLa4wzzgLaYffivHPFQS527awva6y35MFsdKYZmn/PlD7FEqrm3HVQ=='
				),
				_LetterImage(
					width: 42,
					height: 33,
					data: 'eJzN0UEKwEAIQ9Hc/9LtYjZjjfoHCq1L81BQSbpQ6UgKcYXisuNGFr6Uiceg46ZXULJskFv6rVwRlfYc78pEa/nkg9w8ksMcLv1K0zyVyfO/E7kIlu4LP5ZBt+oGCUeXhQ=='
				),
				_LetterImage(
					width: 36,
					height: 33,
					data: 'eJzF0kEOwCAIRNG5/6Vt4qJa/MgsTGUpjyCiJLUiZJrKaQrHZHAx4NAEOJ9lbqkDhJdwzMj8acK8zuueMlGx+cKNeV1hNsWOgRYNf7NjYEFo7J32rGGw9XUzXJ5/APmtUso='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzt0cESABAIBFD//9MZXEhbKwcXHZtnKSJPqlCoF4V8WXSNZoCsZA9NySiCOBxeFA53LuOFPZLqFJBGfk5ubUOC568tb86kROj+FzZjSYCIzX/5JadaVcbQqoA='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJz7/5+mgAEK8MlhUYMuhaoGpyxUDT45Qmbjtp+Q80eeGlTVWA35j0UNVsOx2UpFNfh8iO45bG4eVTMM1AAA6fWtbw=='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJz7/59iwAACmCJQgEUILoEpCJbAJoYhiNUyFHcMQQmENEboYg8J3IFIigSm27BFMabwqAQpEgDeh8lF'
				),
			],
			_LetterImageType.secondary: [
			],
		},
	),
	"R": _Letter(
		adjustment: -5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYMAO/gMBDimqyP1HAtjUDWc5bGppKYct3KkhRys7BkMcYZMDANqCGvQ='
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJzFkUEKwDAQAvf/n7alFELcEZpCiMeMiHGlZVUEt9I7shqacqsrgod1bzByCldqnTcy3Mj/8oXRBrD1YFDN+1L+ApvvYb7U2a16g/52O3S/dhPXPkZEugBUDuAu'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJy90lEOwCAIA9De/9LuYy4SqKVbzPgsT40EAKMvzPKUlsjlKUq5yjSme1kSyroXlFqtk+puOIr9+szAPZWoUou2Sl3gKfZMybaqzt5TaWn6/eID/qZC1qhXuxqgVk9EFTvOlXT/qyAvqMmMkA=='
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJy90kEKACEIBVDvf2lnEWOJ368V5E55WogiojRkRAlyJD5KEBEAHi0ljLLUSnwoBla+B/7r9+tp7K+x4IlS8CMK0r4ShMkaD4719ICuGb0HsLJNEB89PzkzBIwCAKENgJQ8ABN9PqU64g=='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzF0kEOgCAMRFHuf2nU6ELa35kQDHbZvCltQu8fVPPiKguUamPdLQGC1eJRVdbE9Hh9B6M/1RBAlcZOq9hMCpd9N+qL+Nx6gwUFy1KKb8SBKWY/4PRNgm5R9ufksVHx45uVIGcdaeiNjw=='
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJzVkTEKADAIA/3/p+3gJOYUpEObNWeM6L6RhdCwAphW5wXATptJwW3dr4GEinkvgAoVy+4AcI+qDHkjsJlRAPZ+6d0jAGdCFgEHHVS6VA=='
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJzN0DEOACAIA8D+/9M1LEbbGhlhPEG0ZKdQZYCDoZWsODT6pF8ZVw/gfahRpd+9MumzvIeJyQ93em62/XPylhnlBbKhKuQ='
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJy9kkESgDAIA/P/T6MHHYUkTKvW3MpSCKURa4SO7fIEBuOm3ABKHTsqiAs+22BrcQT7AVdh98JnZBqnSMHVzXWQXkexHvMxztZAyTwYVSjYtvPLyvi7fb/DzXfg5bP+wBpGbFGOWcM='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzF01EKwDAIA9Dc/9Lbx2DYmWjKhPppHrRUCwCXVdiSsDiW8mXFiRReysTXoOKkJ6hzWCNDelY+kSvpc8zKRLX88kYGb8mp8k8TdyPdQrJp+jLtsLXzcl4/ZOyOyu1/tOhWvk0haSRlZ8/KyG9pig0e'
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJy90kEOwCAIAEH+/2l6aFIUVyDYyE0cDBJERDQJKZrMyRAVs4OLAYfGwTG3c0sdIGyiYuzmpnH/rUz3L+MVmxkG5nOJOYrK69ip0sZTYcfodM72kCbeMdRj19T32Vxs3gwaqCUTqZvG3AOFxLlj'
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzN0lEOgDAIA1Duf+mZ6Y+OFiqaMD7JoxvLxmgpk9BZEoqlrXU1E4SSI3RLZhHCcHpQutx7mT9Yk1ymiAT5NenaQJLrP1vRnkXJ0P8SLopn2SthKR/2cQGJbyuln4zynaQ36ZOhmnUA3mcSGQ=='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzlkkEKACAIBPv/p+3iRZnVgoIgj+6wuqXZ1RpelQZMliIjVWcqrfPW87v1/2MijSYGDJrT1LOMTIgZcm+PoX3WmfrRmFFZTd48/+lrjMwuHTUzAdFvJvY='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJzVkksKACAQQrv/pY0i+qgDRZty6aMZsQGulYrUaTJWB2pW4Dwx7bIlx4dgYGnXNxGXeAY4GzwAB/RTN8E0IAacEXoMb3wUvxOQAelCbaE='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 43,
					height: 40,
					data: 'eJzVklEKwDAIQ73/pd0GQ7omUVsGY/nUp0bR/SOZNbFLTSxQWWCjXPY2ri43o5DiKG1RhUyMEe3WjKdofjbvoVinUDJiG50TCiX7MlQcBmIcSy+H7iGLKH8UQKUz7oLGGnNG8rbWQmOHrED+wCr68r/KH3ii0k2uX6IFF2jNnToAHyyEpg=='
				),
			],
		},
	),
	"S": _Letter(
		adjustment: 1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJz7////fwYs4D8UUFsOXR0yGExy9DAXmxpayNHLP4NNjgELQFdHihwA4jPeMA=='
				),
				_LetterImage(
					width: 28,
					height: 35,
					data: 'eJy1ktEKACAIA/3/n7YCo6KdEZFPsWOmK/frMgS1SJfMRpG+IgRO+sJotst9ekcmn1i2W7C5RzvN3iyzYNJ7ynv3hiC8JvxfsmKmUPLWT/+adATYiu4XegHHdYeV'
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJy1kUEWACEIQrn/pZtFi3qIQotxVfYTxbXiAJBR8CSu6MXAMZXp0TvbkyUjMacwUeepfJQWFAHpVG0jozyZUYtnmstllEObHRos03UdvoybUZb8vTn9h1V1D2ywdlwkxXKaZfG6Bz8yitB909RB9/EDVs9vuw=='
				),
				_LetterImage(
					width: 33,
					height: 35,
					data: 'eJytkksOwCAIBbn/pW3qwlB4H5rISp9TIWPXmlSEBd6yAIZ2GJ9iHxMoRRhi2xPpSzFwYmehXCo0/TFpEdvmzhwMYo9FENtITTvzaoHRHBe85q2Zo7csyrrBllTNUHrAYg6UjHym/469egARTwAr'
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJy900EOwCAIRFHuf2lMu6gtIH8WVXYmLzhCdP+hjMVVCDpl30JQIBaZYBZ80hq8lGJaJSXapta0nmfsfZ9iQ3FDj0oNa4sRZ0NLqnmThwx4b0lPq8YIv1ZTmAgHxaMUZq0tA8EAKj9xuQ=='
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJz7/58cwAABOCUYMBQwYAcUKMBpN15XE/DR4FGATRWBAMBhD4ZKfKFMvF0kKsCiCiFCgp9wWoZsISFTBlwBDkm65CxkUwHtAYOZ'
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJy1kMEOACAIQvn/n7a11jJh6kVO7VGImXWELQJwGFFtTKlyumw0jaFwkeNctXmeVeLPOeeiE0Wl3zyJ9V3R+WFEMb5vF+mltlg='
				),
				_LetterImage(
					width: 31,
					height: 38,
					data: 'eJy909EKgDAMQ9H8/09XESbbzA04pn0aOyO0Rau+KSU7i0XA6opl1mTFMjE3i0OGKe/oJc5NbWP75rnLIes6jhF5543VMTx5kdCubIJsjN+Gn+BfBs2f14Z/jCVZiuRurBypgB0O'
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJy10uEOgCAIRlHe/6Vtk9aW8NHFJr8anJLAMU6FmXE5g8uKe8li1F8r+btQ8SQnKDmM/PWa1tLLyVFikr9kc5scgxZuzSWivF2xcUJ5D6Tl7hy4RHxHNlaxJ9WLsQPVUdyXWmGaTleu78DKtaz4x4Aew662P18mbDcC'
				),
				_LetterImage(
					width: 36,
					height: 38,
					data: 'eJytkVEOwCAIQ7n/pVkWPxy2xS6BP/FJK82crAiHecthFLjaUUtPkOC3pzh4RyBqwmH2jbGdczhjcEt3xs/Cocb0TE+a43n2lCPZu89RZsCTF98fU+WsBeu5N8UiwBZGxT93Ji8X4DAg0y1pj3gACKmlhQ=='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzV1EEKwCAMRNHc/9IKLZSQmOELEWl2hed0VHCMK2MIPYOQlhYHoRVEaMlINbRRibykrk3u7+WcVLy8nPST9zsFl3VyspMxWSxApT8ZvI/QyZZW6Q4F/4fUDr42XJKG6Mj7UPdrMwFzcDUE'
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJz7/5+mgAEK8MlhUYMuRTU1+JxBwBuEPTmE1ZAaQYRsxKKaQFSRZCs5arApRBIj0Zs4FRKnhnQLB5Ea3PJ0ze8ohgMACjcTGA=='
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJz7/59iwAACmCJQgEWIDAlM03E4BLvrBl6CAbsEVo+gSCArwB5QhIwkRgJVDsoh6EAMOTwSBOKNHhK41GPzArIEAwbAJgEzAAC/3x0A'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJyVkdsOwCAIQ/v/P43LpqalzAsvNidaKkQUBSfIDBD2aPTiC8I+xUzOV5KDk5lDW48At5kHOnlXOcGJMCdlhPOGW7SwApM0xLwOUr+LSZ9zMl1sABENYHqdcQ=='
				),
				_LetterImage(
					width: 43,
					height: 38,
					data: 'eJzF1EEOwCAIBMD9/6dpehJEYLWY7tVB0KaK/BSAZG9IVlPokCyBN9nn7SaaukErNigju7+fOfsuhV6Kqdp70QcubnpbHUVMBeqCeTKiYDF30MdRCfsYmt76xs+YSyGZooSk6cGBGhjb9lrXnifjARlZXto='
				),
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJyVkdsOwCAIQ/v/P43LpqalzAsvNidaKkQUBSfIDBD2aPTiC8I+xUzOV5KDk5lDW48At5kHOnlXOcGJMCdlhPOGW7SwApM0xLwOUr+LSZ9zMl1sABENYHqdcQ=='
				),
			],
		},
	),
	"T": _Letter(
		adjustment: 2.5,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 24,
					height: 29,
					data: 'eJxjYBga4D8UoPNHxUemOABcPl6w'
				),
				_LetterImage(
					width: 24,
					height: 33,
					data: 'eJz7/x8rYMAqCARYBTHEGeAAqyCSOAMawCoIFsciCBTGKojNCHz2kSuOJI8QR9WHI7hGxQelOIIPABZuwU0='
				),
				_LetterImage(
					width: 34,
					height: 33,
					data: 'eJzt0aEOAEAIAlD+/6fPYJFN4YpNmuwFNwA8HWS8EAocLxrWCVaTIKXQl/Iv7Yl6qAG8yNKJaYATJ5SqVQCAcoGb'
				),
				_LetterImage(
					width: 29,
					height: 33,
					data: 'eJxjYPiPGzCAAV5JHAoYkAFeSXQFGJLI8tgkkRTgkiakAK/tVJX8j1cSzsMlCRbBJ4ktIEclh4UkXB7BBwBxTSvx'
				),
				_LetterImage(
					width: 34,
					height: 33,
					data: 'eJzt0UEKACAIAEH//2lD8JCiK9RVj+0gRao8IlxtuHZCwmDMoqiXaKoLqNa50vrpesPzXkXCSRTrxs9aseJLxOMDhXiDmQ=='
				),
				_LetterImage(
					width: 29,
					height: 31,
					data: 'eJz7/x8XYGBgwC4KBVgFkSUxRQcKYHcMPvejSaIpwxFco5KjkmRIAgCn4fEd'
				),
				_LetterImage(
					width: 19,
					height: 31,
					data: 'eJz7/x8NMDCg8sAAjQsVYqAZQDMbw3IkIUxHYnH3qBBthaAcAD6lLuA='
				),
				_LetterImage(
					width: 26,
					height: 36,
					data: 'eJztkEEKACAIBPf/nzYhKJOdW6dojzMuihEQkSCjDGBjtOLpYdQDeBqHUwD2BVosPOmCqSPFtDJ9+Jv3zAYDB1ERDA=='
				),
				_LetterImage(
					width: 37,
					height: 36,
					data: 'eJztzjESACAIA8H8/9NaWAiKJI2OBdeR2QIAaCyoiEKYJHSUG4pkjBaZoBtQ+u8T5M4EzYmgMQvIV6jQc2Sl2zr04/8d'
				),
				_LetterImage(
					width: 32,
					height: 36,
					data: 'eJztzjEOACAIQ9He/9KYOJASsXVzgQl5fxBAqIF3qAY0zrsE5zgvzcW5EYlv3F++eFlbz6fwfTIe4+OvngkdFlxFuWM='
				),
				_LetterImage(
					width: 37,
					height: 36,
					data: 'eJzt0TsKACAMRMG9/6UjChb5+TpBcNsdQ4JmGIkNI60g6JF8qE+o6h1qwUZHMAkCmMLL4sUXUHyQUDW1/tOPPnoAhWIAQmMFJg=='
				),
				_LetterImage(
					width: 32,
					height: 34,
					data: 'eJz7/x8PYGBgwCeNU54BAXCJo8hjER8UAJfT8HsJUx5dLQnyWINvVH5UfpDIAwCiPX6e'
				),
				_LetterImage(
					width: 21,
					height: 34,
					data: 'eJz7/x8DMDBgimEIMkAAOh8uyEB7gGEJpktQBJHk8Aii+WdUcNALQnkAEVFxnQ=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 39,
					height: 36,
					data: 'eJzt0jsOACAIBFHuf+nVzsgnToyxYuoXoEAiGTEzQE7MVsSUzHyAJCw1Tt2bV6sY+sYEWBgdWXqBY9WhKmvWjLNaiRi5V94afIFL3w=='
				),
			],
		},
	),
	"V": _Letter(
		adjustment: 3,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ2Myo3KIYvhYlMih27/fzRArhxMHps4qXIAbZyKhA=='
				),
				_LetterImage(
					width: 28,
					height: 33,
					data: 'eJz7/x8nYMAlDgI4JWgqh6oGIYepnwENjMrRXA5rPML4pMgh83HIoapDUovNvZhyqHpJ8ysFaRnNHdj0IvMB8pz7Ew=='
				),
				_LetterImage(
					width: 38,
					height: 32,
					data: 'eJzt0jEOACAIA0D+/2lcMJECUjcGO5aTRKOIaB+xcOoOR6mja5QNGOXy1Uil9afGBS8KWaFAJi2ndps/QjjLqWTu71WpGFxDqSI5WJ+JiZM='
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJzt0TEOACAIA0D+/2kdMApY28m42E16JhjNrNGYR4IzeQfWhACfChDywW0wDwTEzyUgEwii2XaTYIzAE8sdCWqXVkegJnUSoICyAzcuNuY='
				),
				_LetterImage(
					width: 38,
					height: 33,
					data: 'eJz7/58wYGAgqAAMCKsYWFVYNKCqwmUsA1YwqmqYq8Kb1JAEKVGFLkhAFaZH/qPpxeNdnKowDSQQMliMRTOQunkZoRSPqv+4VQEAblurcQ=='
				),
				_LetterImage(
					width: 33,
					height: 30,
					data: 'eJztjjESACAIw/j/p6t3OogtKDsZaYACCTZJosWfwKYxLbTwEpwq9kGCGF3PhBDs+EaiM5iSIOL9OY7PM340ABzO9hg='
				),
				_LetterImage(
					width: 23,
					height: 30,
					data: 'eJz7/x8LYGDAIgQCuIVRZRmQwajwQArDJVHU/kcSRuH8RzEHRSuqMHa7UVMIAeH//9GE/2MKwjQgOABhg16w'
				),
				_LetterImage(
					width: 31,
					height: 36,
					data: 'eJzt0MEKACAIA1D//6eNbrrNnSII2rGnkma6hFXHsePsEmNdYTUmMJ/f4DTcphzi9jIz1LYGvaBiHEEfpRshjxvKfQTXawwhXpBae6E='
				),
				_LetterImage(
					width: 42,
					height: 35,
					data: 'eJztzzEOACAIA8D+/9O6GKLYxjo4GO1GuQEAoFjBloTF0eda2beGbCtXpnz5jBzmpYzmhJyollnT3pexIEhIcpCS1ORvtWSZjC9lFKoLIBAb'
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzt08EKACAIA9D9/0/XoYMtl0qngnZLH0iCANCSoGgyB+TqDmO12Ix6buZ884KxV2z0dZyaVWnDztcqhuZtt+KWEc7nNv9FGx9uV4yOanfNyLxg'
				),
				_LetterImage(
					width: 42,
					height: 36,
					data: 'eJzt07EKACAIBFD//6dtaJHTsyMIGnS0p6GRuxZmItSk7ZDQT7IsQ8kvMBYjR15LqCKy6P9aprQgqz04HvQb6yT81m5E+halxIKMWOuDDLyXsXHKL4tiNvQ='
				),
				_LetterImage(
					width: 36,
					height: 33,
					data: 'eJztzzEOACAIBEH+/2m0IjmzgtrYsCWZILrn2awghbHo3JA2qE2bP0b1tZHhYnhIV+FyMi//3L6aGQJxRCZUagP8h3Op'
				),
				_LetterImage(
					width: 25,
					height: 33,
					data: 'eJzt0sEKACAIA9D9/08vCMQ2Rp6DdrMXaSAZA+TzDNi5gl2A5MOb0DxDVQ043tdOClZpO53PdnAG0sE31T9WWTWcsF4='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 32,
					data: 'eJxjYPiPBhiAAFOEgdoiYBaaCJCNIcIwPETAFHpAYBNhwBSBisFZUPPQ5BBW4xaB8xlwORbhXGSR/8gKUBwOALTPOdU='
				),
				_LetterImage(
					width: 18,
					height: 34,
					data: 'eJzN0MESABAIRdH7/z8dYxJ6zVjSRh0LL1guQAUVXsjokqDi9ZGYim9zFVRIXxPE3lXiSdZdBM7xz3frJc0O6ccuc2xrvVyy'
				),
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJzV0jEOwCAMBMH9/6edJjLHBgkailzHWAjpTNUu8AF8vi1YkORVOr8SFXAgSEY5ITnBgmXqksj7YmONsNyc/w25tAc08m6g'
				),
				_LetterImage(
					width: 43,
					height: 35,
					data: 'eJzt0tsKgDAMA9D+/09XdEzqTJbgiwyWx/bsVpbpJkx2xnWaRokv16RwGaDshIHOLhMsm/5BxTd/dCwKjvhMxwajoCwoHcdVqHVyoT45i/Y2eeibsoFkq2hX955MAy+4f4Wi7O0tB3YEWNI='
				),
				_LetterImage(
					width: 18,
					height: 32,
					data: 'eJxjYPiPBhiAAFOEgdoiYBaaCJCNIcIwPETAFHpAYBNhwBSBisFZUPPQ5BBW4xaB8xlwORbhXGSR/8gKUBwOALTPOdU='
				),
			],
		},
	),
	"W": _Letter(
		adjustment: -1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 28,
					height: 29,
					data: 'eJxjYICA/0iAAQ2MylFfDpkelaM+QDYfnU2uHADQ8A8A'
				),
				_LetterImage(
					width: 28,
					height: 35,
					data: 'eJz7/x8nYMAlDgI4JWgqh6oGIYepnwENjHg5KI1NjmEEyCEL4ZJD5mNowmI2TjkEHyM+kN2KTQ41HonIG1jEAVJIuFY='
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJzt0jEOACAIA8D+/9M6QKKQYhkd6IR4bAWwdODpqTf8Sl07ofyjo0JGBYWeyuOoSqFW/IYo4npKXtXqgrwOuVBa1dVSyl5cHWrjBvxGSdM='
				),
				_LetterImage(
					width: 33,
					height: 35,
					data: 'eJzl0zEOACAIA8D+/9OYgEbRAqMDnRBuMEQBSBpYShCTf2B3EmDdAhzpBFCCVfUFOiCA6AfcpATR3fQUAP+HKZiDHPC3kAGtCXArlQELWgIb'
				),
				_LetterImage(
					width: 38,
					height: 35,
					data: 'eJz7/58wYGAgqAAMCKsYWFVYNKCqwmUsA1Ywqop2qhBMPKowmKOqiFCFLkFIFUZk4TAHt+UEVaGK4kge6AkDnyosSY3EcgO3AgCWDEvR'
				),
				_LetterImage(
					width: 33,
					height: 31,
					data: 'eJz7/x8PYAACPFIQQJwCTJUMmGBUAX0VwFmjCohSgEUapz78gJAmLNGGKkScAqx6kFMGAFIXhYk='
				),
				_LetterImage(
					width: 23,
					height: 31,
					data: 'eJz7/x8LYGDAIgQCuIVRZRmQwUgXhkoOK2EGBjRhBsIAuyIUGxAc3MJoamChDgDLXRX5'
				),
				_LetterImage(
					width: 31,
					height: 38,
					data: 'eJzt0TEKACAMA8D8/9MVBbWtMYODUzNJToKgmQqkKkaPsk+c7zlmM8gpfud54IziG4dScCj43lFKdg15zGr4v1vO6O68J6g09QMw7A=='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJzt0jEOACAIQ9F//0vroAMikDo4mNgJ8XUDoEnhSCJxbJ6VdivI+aVKly8vSHS5z1/ellQybYYytLqMq2u3lBZnB7dfriZd6ViOZyoNH3MHKkO1Zw=='
				),
				_LetterImage(
					width: 36,
					height: 38,
					data: 'eJzt1DsOACAIA9De/9KaSPyDrZuDTALPhDAAAIkERMMcwNUbptfOxurcjPGNYqCY9vzm3ljLM+4Px2xKMfGklodmuTGBqS1mJqybkrhm2XgGH2x/nQ=='
				),
				_LetterImage(
					width: 42,
					height: 38,
					data: 'eJz7/584wMBApELiVDJAAFGKBpNKrNrQVeK2gAEXGFU5VFQisfGrxMIeVUlPlRhSxKjEkgZwmofXJcSoRJfAmQKRJfCnVYzkjKSSnNIPnxoAUWS5Yw=='
				),
				_LetterImage(
					width: 36,
					height: 34,
					data: 'eJz7/x8/YAACAkoIqGGAA+LVYFPNgAWMqhmKahDMUTV0UINNAT7NBAERGrEajiZItBr09ATloqQ2AHxt+BY='
				),
				_LetterImage(
					width: 25,
					height: 34,
					data: 'eJz7/x8rYGDALo5dggEM8EqgKWBAAaMSJEnA5EeqBAMDugS6CHaASx2qTUgW45NA4yFiDAAeNVW5'
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJzN0kEKACAIRNF//0tPEkKM07JFruQxJEqgUVSl8Fp2N6T6EH6Vs8AHgh/Uglg2ZWR97XivZ7tIN+lJ8QmkBcrNJOo='
				),
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJzF0jsKADAIRMF3/0sbCH7QbawSKxnBYhWbBaigwg+53RBUvB4LKvyQiKOF5YMh7KR25qIWRN6golGxnYTNJzA72BxatA=='
				),
				_LetterImage(
					width: 18,
					height: 38,
					data: 'eJzF0jEOACAIBMH9/6exMOh5xFgZqHBQCiTiFVAAP/8WXDDRp6zoF1xol5luyeJVcDk7Zp4z0Nth4kMqop9fNm0AD6patA=='
				),
				_LetterImage(
					width: 43,
					height: 38,
					data: 'eJztz0EKACAIBED//2kjiIrVTbFT0J7EpkzVbCTJerIuprIlL9+k7jWHsglAT58Rlk8LdNUBtfWno3OgeMIoHVej0RLOxxHyR4D5dPYVwueZ3FAqlS5h0wBi+RsQ'
				),
				_LetterImage(
					width: 18,
					height: 35,
					data: 'eJzN0kEKACAIRNF//0tPEkKM07JFruQxJEqgUVSl8Fp2N6T6EH6Vs8AHgh/Uglg2ZWR97XivZ7tIN+lJ8QmkBcrNJOo='
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
					height: 29,
					data: 'eJxjYICA/0iAAQ0Mdjl8bGrIYbOfXDl0+f9ogNpytPADMp8acsS4ezDIAQBYYFK8'
				),
				_LetterImage(
					width: 28,
					height: 36,
					data: 'eJy9kTEOACAIA/n/pzEOKJSSaCJ2Ao4qqGopqepTJWhlsWez7DfEzrb8hvn8iJFeccosenE0AbF3eMDcTt/uLMieJxTAy2LGrv+QzGwx2WdFwJIf1ccYUR2M+BgF'
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzN1MEOwCAIA9D+/09rMk1k2ALLPMgN+jTEgwBaXphVUzG8Sr1nkbJBombELxPKyUMKrrahVmRuc7UH3fOkGl1BqcVLKt3ou3o6G1HJL9A9Wk2xRf+rFW0HY7VeRLyiD7i64QvhsgM1pNlD'
				),
				_LetterImage(
					width: 33,
					height: 36,
					data: 'eJzF0FEOgCAMA9De/9IzBiPOtlskRvcF5cEWAERZGNUCT/4DKXHgknpw5PyGBNx2FSCV8ALcw3kmu/JEL4B93QB11oKy/wOANGAwEhftrgU00TI443yjACPQPxOu7J9+CCbaALSwfp4='
				),
				_LetterImage(
					width: 38,
					height: 36,
					data: 'eJzFkEEOACEIA/n/p11j9oB1gBiza280Q0lprZZZCQzVxF0KFmYqinVMctyZJ5Sa+xS5C4Wu+5MGciMNTDp/Tsl7IlYD/6a4wFvBFgR31ORkptDdouLObg4/M01EBbGse1SCdD0PcNpC'
				),
				_LetterImage(
					width: 33,
					height: 32,
					data: 'eJzFkFEKACAIQ73/pa0IAnPTwqD9hPVmTtVA0hU8TZ0BnhSvT4BBgV8dAK62zwAQecKZy4ANnQMkTgkA1OuYDEhXvVXEMw7BHjTVKl9u5QIgoUkvBjS+sP4Q'
				),
				_LetterImage(
					width: 23,
					height: 32,
					data: 'eJy1ktsOACAIQvn/n6b10gTtsjZ565hZEFkIKNDUHmsVUQ14FWUvA5YF5RxpPWOf/4TrB6h3vzg58XNBx3dP4HZa8hZE44dIyVuP4wHCIFa4'
				),
				_LetterImage(
					width: 31,
					height: 40,
					data: 'eJzF0EEWgCAIBNC5/6Wn18JyZCAXVKyUr4CSVaDUinFGZR/xem5iV2YofJeR6WbJbLO9AAnHa4kwK0LYL2xk89SM/xgvx2k8TYUKsntgyXSxfea1oeN7GThp6//yRfZIHubzoXs='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzV0FEOgDAIA9De/9L6YTSABaqSLPI3+kY2AGCTCo8kJA5bv5Wx20gX9fIMs6ETMuphiVikXUqWeBN+W8hiKZ/l9ZhZmRtdKl95KY+zSxOezrl1PNIlf/oCaVJyvZVmsVTSKJWdXSst3wF6232t'
				),
				_LetterImage(
					width: 36,
					height: 40,
					data: 'eJzN1EsKwCAMBNC5/6UtRYoxTj5+CrrL5KnBhQBQgoWkiRwQqztMn9lG5p75OuykdcOm3DLolzYwzRCLNr+fHHHQvMUZw9sZE807Z2olOsTR3U6ZMWS8/03rqG2+qYn1rjpn5pafqbkHqnEOHQ=='
				),
				_LetterImage(
					width: 42,
					height: 40,
					data: 'eJzN0N0KwCAIBWDf/6UbYzCa5ycJwnmXfKfMMWoVUYQ1GU+V0J8kjWWpH5hd5BiReP9xCe1dOXEvYyXThkVU3UxQj1TLW0sTwBkapfrU+wXCRBLb6g0pRf+kdGv7dMyC05lLtgyQapJGadVdF9adg6c='
				),
				_LetterImage(
					width: 36,
					height: 35,
					data: 'eJzN08EKACAIA1D//6etU1FtKlbUbsXDmJCqHalxiGOkJW6QFpD3xmg4XE4GX6IXEwbu1DG8bNZkdkobHjAI3uq+Z9DRMx0uBgwLzP7kD9JV0IncFHiZZrY='
				),
				_LetterImage(
					width: 25,
					height: 35,
					data: 'eJy1klEKACAIQ3f/SxsEYc5VUuRX9Za4lZksQJ9rgF5bQAKE+gccR73NAFOb2LAIaCdBnrEKVlYp8CeAc6TPPhIohZhk/qgOaPKxuvZ6BOJf8b0EGhUvpWk='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJyt0UEKwCAMRNF//0vbYq2ZcSoU2mxMHhJCAm0JzkjhbxmZyZW7YJ9EqoEKKSMeZea9lo7145WQImXK2mUj4APq7Pa2lGpnm0+Z+025R5frbM75QbodD7FVuQ=='
				),
				_LetterImage(
					width: 18,
					height: 36,
					data: 'eJyt0UEKwCAMRNF//0vbYq2ZcSoU2mxMHhJCAm0JzkjhbxmZyZW7YJ9EqoEKKSMeZea9lo7145WQImXK2mUj4APq7Pa2lGpnm0+Z+025R5frbM75QbodD7FVuQ=='
				),
			],
		},
	),
	"Y": _Letter(
		adjustment: 1,
		images: {
			_LetterImageType.primary: [
				_LetterImage(
					width: 24,
					height: 29,
					data: 'eJxjYICA/1DAgAZGxbGL08MudPtGxRHiAKpERsg='
				),
				_LetterImage(
					width: 24,
					height: 33,
					data: 'eJz7/x8rYMAqCARYBbGIM1AijiSPEEfVx4AGBok4hv9gbOLEEWwkcRS70O3HKQ63B1UOW5gTLU5s/A1ZcQQfAJtLqWU='
				),
				_LetterImage(
					width: 34,
					height: 33,
					data: 'eJztzzEKACAMA8D8/9M6VDDFNhVEXMzWcKAB0HRgqYVQ9wQfmZiFElZWwuWpoDMXfv6ZICXE6IIByTzx+KawshIuy1+1CPNFqrjqWA5Wxg=='
				),
				_LetterImage(
					width: 29,
					height: 33,
					data: 'eJzl0TEOACAIA8D+/9OYMECIbRdNHOwkXgeJQOggY1EUriIs1qQwbxziBfZZbXeI5QLnI/YyX4AVFM6/IxgEwyLJL1je8wJ45gEc'
				),
				_LetterImage(
					width: 34,
					height: 33,
					data: 'eJzt0MEKACAIA9D9/08b3ZptUlCHoB31McSIOkC97am3XgBXRMJJiDroPC5IT2Lq2xA8SEIcZq5eEHSTYJFzRvjXmKYvRsHjBuSMWMQ='
				),
				_LetterImage(
					width: 29,
					height: 31,
					data: 'eJz7/x8XYGBgwC4KBQQl0ZQxYAGjklgksYcygockiWkOpjCaOaRI4oxeLJKoKkYliZcEAFzbxkg='
				),
				_LetterImage(
					width: 19,
					height: 31,
					data: 'eJz7/x8NMDCgcUEAuxBCggEJDE0hVJ8iPIgkhSSEbgReIbSAQxFCiA5pISgHAB4lKeU='
				),
				_LetterImage(
					width: 26,
					height: 36,
					data: 'eJzd0bsWABAMA9D8/0+Xra+EgYVselU5zESgQAlmRJkKjiVuCVKaUfOSGJfUuxVfRMlD201W4ucWpp91SeiTW99f4oUBVZr9EQ=='
				),
				_LetterImage(
					width: 37,
					height: 36,
					data: 'eJztz0EOABAMRNG5/6VZlOgIbSVNRGJ2vrcAAIo3RJELoXYR0dFAIzlIcgDxnkI6mKinPKSljVpd/mj7ZfMdB0hyAPGm2zy03kcxpCW1CnKTzU8='
				),
				_LetterImage(
					width: 32,
					height: 36,
					data: 'eJzl0kkKACAMA8D8/9MRK4ilGyKIYE9txoMbAGaF2pGtwVLXXLWuzzFxiQrH675OgesLOXA7OkGP7J6DE+k333SJCqfroz1xt353mo9ENoYtba8='
				),
				_LetterImage(
					width: 37,
					height: 36,
					data: 'eJzt0LkNACAMA0Dvv3SQqEicDwnRgEu4mEekDFCbGmGmBBnCmvPIDhDyWhHlSaQnHMS1m8gsEfKuGb6iifTpHhXOdZR9bNj3UQeZjQEmZtBM'
				),
				_LetterImage(
					width: 32,
					height: 34,
					data: 'eJz7/x8PYGBgwCeNU54BAYiSR1fLgB2MylNZHk0pmjyGUWjmIuSxW4g9womR/48OCMmjqRqVp5s8AKA1MOw='
				),
				_LetterImage(
					width: 21,
					height: 34,
					data: 'eJz7/x8DMDBgimEKMoABTkEkOQZkMLwF4VIoYghBZE0MGACb6VgE0YMbTRBJfGQIQnkAUohynA=='
				),
			],
			_LetterImageType.secondary: [
				_LetterImage(
					width: 14,
					height: 33,
					data: 'eJxj+I8MGBgYUHlIfHJ4IAqZBwUU8/6j8iAW4eahUwyoPEIWI3sLH4+KAUcaDx5xAH2C+gY='
				),
				_LetterImage(
					width: 39,
					height: 36,
					data: 'eJzl0MEKgDAMA9D8/09XLyI2yRr0MjDH7q2UVCVBYs4EZGK4E6ENGAJGq5nJCxpzh8LmK1u085hObCoxZAgYjZjJj23oboDN664lbsztLA7EUs2WXaulf2NeVWIuJl8OZlwlBg=='
				),
				_LetterImage(
					width: 14,
					height: 33,
					data: 'eJxj+I8MGBgYUHlIfHJ4IAqZBwUU8/6j8iAW4eahUwyoPEIWI3sLH4+KAUcaDx5xAH2C+gY='
				),
			],
		},
	),
};
