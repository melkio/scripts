properties {
	$current_directory = Resolve-Path .
	$solution_directory = Join-Path $current_directory -ChildPath "src"
	$artifacts_directory = Join-Path $current_directory -ChildPath "artifacts"
	$packages_folder = Join-Path $solution_directory -ChildPath "packages"
	
	$web_projects = @()
	$service_projects = @()

	# tools
	$nuget = Join-Path $current_directory -ChildPath "tools\nuget\nuget.exe"
	$nunit = Join-Path $current_directory -ChildPath "tools\NUnit.Console\tools\nunit3-console.exe"
	$nuget_server = ""
	$api_key = ""

	#config
	$test_project_filter = "*Tests" 
	$config = "Release"
	$build_number = "0"

	#options
	$clean_packages = "false"
}

Framework "4.5.1"

#task default -depends run_tests
task clean -depends clean_artifacts, clean_packages, clean_solutions 
task build -depends clean, build_solutions
task prepare_artifacts -depends run_tests, prepare_web_artifacts, prepare_service_artifacts

task dev -depends run_tests
task deploy -depends publish_packages

task clean_artifacts {
	$exists = Test-Path $artifacts_directory
	If ($exists -eq $True) {
		Remove-Item $artifacts_directory -Force -Recurse 
	}
}

task clean_packages -precondition { return $clean_packages -eq "true" } {
	$exists = Test-Path $packages_folder
	If ($exists -eq $True) {
		Remove-Item $packages_folder -Force -Recurse 
	}
}

task clean_solutions {
	Get-ChildItem $solution_directory -Filter "*.sln" |
		ForEach-Object {
			Exec { msbuild $_.fullname /t:Clean /p:Configuration=$config /v:quiet /ds }
        }
}

task restore_nuget_packages {
	Get-ChildItem -Path $solution_directory -Filter "packages.config" -Recurse |
		ForEach-Object {
			Exec { . $nuget install $_.fullname -OutputDirectory $packages_folder -NonInteractive }
		}
}


task build_solutions -depends restore_nuget_packages {
	Get-ChildItem $solution_directory -Filter "*.sln" |
		ForEach-Object {
			Exec { msbuild $_.fullname /t:Build /p:Configuration=$config /v:quiet /ds }
        }	
}

task run_tests -depends build {
	Get-ChildItem $solution_directory -Filter $test_project_filter -Recurse |
		ForEach-Object {
			$fullname = $_.fullname
			$name = $_.name

			Exec { . $nunit "$fullname\bin\$config\$name.dll" }
        }	
}

task prepare_web_artifacts -depends run_tests {
	$web_projects |
		ForEach-Object {
			$project = $_
			$artifact = Join-Path $artifacts_directory -ChildPath $project
			
			Copy-Item -Path "$solution_directory\$project\assets" -Destination "$artifact\assets" -Recurse
			Copy-Item -Path "$solution_directory\$project\bin" -Destination "$artifact\bin" -Recurse
			Copy-Item -Path "$solution_directory\$project\Views" -Destination "$artifact\Views" -Recurse
			Copy-Item -Path "$solution_directory\$project\*" -Destination "$artifact" -Filter "Web*config" -Recurse
			Copy-Item -Path "$solution_directory\$project\*" -Destination "$artifact" -Filter "*.ico" 
			Copy-Item -Path "$solution_directory\$project\Global.asax" -Destination "$artifact" 
        }
}

task prepare_service_artifacts -depends run_tests {
	$service_projects |
		ForEach-Object {
			$project = $_
			$artifact = Join-Path $artifacts_directory -ChildPath $project
			
			Copy-Item -Path "$solution_directory\$project\bin\$config" -Destination $artifact -Recurse
        }
}

task package_artifacts -depends prepare_artifacts {
	$package_template = Join-Path -Path $current_directory -ChildPath "template.nuspec"

	Get-ChildItem -Path "$artifacts_directory" -Exclude "*.nupkg" |
		ForEach-Object {
			$project_name = $_.name
			$nuspec = Join-Path -Path $_.fullname -ChildPath "$project_name.nuspec"
			Copy-Item $package_template $nuspec

			$assembly_info = Join-Path -Path $solution_directory -ChildPath "VersionInfo.cs"
			#$assembly_pattern = "[0-9]+(\.([0-9]+|\*)){1,3}"
			$assembly_version_pattern = "^[^']*(AssemblyFileVersion[(""""].)([^""""]*)"
			$assembly_info_content = Get-Content $assembly_info
			$version_group = $assembly_info_content -replace " ", "" | 
				Select-String -pattern $assembly_version_pattern | 
				Select -first 1 | 
				% { $_.Matches }              
		    $assembly_version = $version_group.Groups[2].Value 

		    [xml] $spec = Get-Content $nuspec
		    $spec.package.metadata.id = $project_name
		    $spec.package.metadata.version = "$assembly_version.$build_number"
		    $spec.package.metadata.description = $project_name
			
			$spec.Save($nuspec)
			
			Exec { . $nuget pack $nuspec -OutputDirectory $artifacts_directory }
		}
}

task publish_packages -depends package_artifacts {
	Get-ChildItem $artifacts_directory -Include "*.nupkg" -Recurse | 
		ForEach-Object {
			Exec { . $nuget push -Source $nuget_server $_.fullname $api_key }
        }
}