Repository.define do
    repositories provider: :github, namespace: 'StratusNetwork' do
        repository :data do
            klass           Repository::Data
            repo            'Data'
            branch          'master'
            services        [:data]
        end

        visible? true do
            repository :plugins do
                title           "ProjectAres"
                description     "Our custom Bukkit plugins (such as PGM) that control matches and add network features to Minecraft"
                repo            "ProjectAres"
                open?           true
            end

            repository :sportbukkit do
                title           "SportBukkit"
                description     "Our open source fork of Bukkit that is finely tuned for competitive Minecraft"
                repo            "SportBukkit"
                open?           true
            end

            repository :docs do
                title           "Website"
                description     "Our website repository"
                repo            "OCN"
                open?           false
            end

            repository :rotations do
                title           "Rotations"
                description     "Our map rotations on our servers"
                repo            "Map-Rotations"
                open?           true
            end
        end
    end
end
