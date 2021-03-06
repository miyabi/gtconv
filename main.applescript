function run() {
	let musicAppName = 'Music'
	let musicApp

	try {
		musicApp = Application(musicAppName)
	} catch (e) {
		try {
			musicAppName = 'iTunes'
			musicApp = Application(musicAppName)
		} catch (e) {
			musicApp = undefined
		}
	}
	
	if (!musicApp) {
		alert('Music または iTunes が見つかりませんでした。', { withIcon: 'caution' })
		return
	}


	if (!musicApp.running()) {
		alert(`${musicAppName}を起動して、対象のトラックを選択ください。`)
		return
	}

	const selectedTracks = musicApp.selection()
	const selectedTrackKeys = Object.keys(selectedTracks)
	if (selectedTrackKeys.length < 1) {
		alert(`${musicAppName}で対象のトラックを選択ください。`)
		return
	}

	// To request permission to Finder here
	const finderApp = Application('Finder')
	finderApp.includeStandardAdditions = true
	let destinationFolderPath = finderApp.pathTo('desktop', { from: 'user domain' })

	const currentApp = Application.currentApplication()
	currentApp.includeStandardAdditions = true
	
	try {
		destinationFolderPath = currentApp.chooseFolder({
			withPrompt: '保存先のフォルダを選択してください',
			defaultLocation: destinationFolderPath,
		})
	} catch (e) {
		if (e.errorNumber === -128) {
			// Cancelled
			return
		}
		return e
	}	
	
	let startFileNumber
	while (1) {
		const startFileNumberString = prompt('開始番号を入力してください（000〜127）', '000')
		if (startFileNumberString === undefined) {
			// Cancelled
			return
		}
	
		startFileNumber = parseInt(startFileNumberString, 10)
		if (isNaN(startFileNumber) || startFileNumber < 0 || startFileNumber > 127) {
			alert('000〜127の範囲で入力してください。', { withIcon: 'caution' })
			continue
		}
		
		break
	}
	
	if (startFileNumber === undefined) {
		return
	}

	if (!finderApp.exists(destinationFolderPath)) {
	}

	// Convert tracks to MP3
	const prevEncoder = musicApp.currentEncoder()
	musicApp.currentEncoder = musicApp.encoders.byName('MP3 Encoder')
	
	let fileNumber = startFileNumber
	const trackCount = selectedTrackKeys.length

	Progress.totalUnitCount = trackCount
	Progress.completedUnitCount = 0
	Progress.description = '変換中...'
	Progress.additionalDescription = ''

	selectedTrackKeys.forEach((key, i) => {
		if (fileNumber > 127) {
			return
		}
	
		const track = selectedTracks[key]

		Progress.additionalDescription = `変換中のトラック（${i + 1}/${trackCount}）: ${track.name()}`
		delay(1/60)

		const convertedTrack = musicApp.convert(track, { timeout: 600 })[0]

		// Move and rename converted track
		const movedFile = finderApp.move(convertedTrack.location(), {
			to: destinationFolderPath,
		})

		const fileName = `DS${fileNumber.toString().padStart(3, '0')}`
		const fileExtension = movedFile.nameExtension()
		movedFile.name = `${fileName}.${fileExtension}`
		
		// Delete converted track from library
		musicApp.delete(convertedTrack)

		Progress.completedUnitCount = i + 1
		delay(1/60)

		fileNumber += 1
	})

	musicApp.currentEncoder = prevEncoder
	
	const processedCount = fileNumber - startFileNumber
	if (processedCount < trackCount) {
		alert(`${trackCount - processedCount}のトラックを変換できませんでした。`, {
			buttons: ['終了', 'フォルダを開く'],
			defaultButton: 'フォルダを開く',
			cancelButton: '終了',
			withIcon: 'caution',
		})

		finderApp.open(destinationFolderPath)
		finderApp.activate()
		return
	}
	
	try {
		alert('変換が完了しました！', {
			buttons: ['終了', 'フォルダを開く'],
			defaultButton: 'フォルダを開く',
			cancelButton: '終了',
		})
		
		finderApp.open(destinationFolderPath)
		finderApp.activate()
	} catch (e) {
		if (e.errorNumber === -128) {
			// Cancelled
			return
		}
		return e
	}
}


function displayDialog(message, options = {}, app = Application.currentApplication()) {
	app.includeStandardAdditions = true
	return app.displayDialog(message, options)
}

function alert(message, options = {}, app = undefined) {
	return displayDialog(message, { buttons: ["OK"], defaultButton: "OK", ...options }, app)
}

function prompt(message, defaultAnswer = '', app = undefined) {
	try {
		return displayDialog(message, { defaultAnswer }, app).textReturned
	} catch (e) {
		if (e.errorNumber === -128) {
			// Cancelled
			return undefined
		}
		return e
	}	
}
